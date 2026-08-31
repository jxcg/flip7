import Accessibility
import Foundation
import Observation
import SwiftUI

#if SWIFT_PACKAGE
  import Flip7Core
#endif

@MainActor
@Observable
final class GameSession {
  struct TurnOutcome: Equatable {
    let playerID: PlayerID
    let messages: [String]
  }

  var humanName = "" {
    didSet { setupError = nil }
  }
  var opponentCount = Ruleset.minimumPlayerCount - 1 {
    didSet { setupError = nil }
  }
  let humanPlayerID = PlayerID(rawValue: 0)
  /// Sampled fresh per computer decision, so the table does not tick like a
  /// metronome. Tests set both bounds to zero.
  var turnDelayRange: ClosedRange<Duration> = .seconds(2)...(.seconds(4))
  private(set) var opponentTask: Task<Void, Never>?
  private(set) var setupError: String?
  private(set) var commandError: String?
  private(set) var turnOutcome: TurnOutcome?
  private(set) var inputVersion = 0
  private(set) var engine: GameEngine?

  var state: GameState? {
    engine?.state
  }

  var actingPlayerID: PlayerID? {
    guard let state = engine?.state else {
      return nil
    }

    return switch state.phase {
    case .awaitingTurn(let playerID):
      playerID
    case .awaitingAction(let decision):
      decision.sourcePlayerID
    case .waitingToStartRound, .dealingOpeningCards,
      .roundComplete, .gameComplete:
      nil
    }
  }

  /// True when the human seat owns the current decision. Views gate their
  /// controls on this: a computer's turn must not offer buttons that silently
  /// do nothing when tapped.
  var isHumanTurn: Bool {
    actingPlayerID == humanPlayerID
  }

  /// What VoiceOver should say about the current decision. Kept separate from
  /// the outcome so a turn is still announced after a result is shown.
  var turnPrompt: String? {
    guard let state else {
      return nil
    }
    switch state.phase {
    case .awaitingTurn(let playerID):
      let name = state.playerName(for: playerID)
      let canStay = state.players.first { $0.id == playerID }?.hasCardInFront == true
      return canStay
        ? "\(name)'s turn. Available actions: Hit or Stay."
        : "\(name)'s turn. Available action: Hit."
    case .awaitingAction(let decision):
      let targets = decision.legalTargetIDs
        .map { state.playerName(for: $0) }
        .joined(separator: ", ")
      return "\(state.playerName(for: decision.sourcePlayerID)) must choose a target for "
        + "\(decision.card.displayName). Available targets: \(targets)."
    case .roundComplete(let summary):
      return "Round \(summary.roundNumber) complete."
    case .gameComplete(let result):
      return "\(winnerNames(for: result, in: state)) won with \(result.winningScore) points."
    case .waitingToStartRound, .dealingOpeningCards:
      return nil
    }
  }

  var actingPlayerName: String? {
    guard let state = engine?.state, let actingPlayerID else {
      return nil
    }
    return state.playerName(for: actingPlayerID)
  }

  /// `GameEngine` trims and lowercases names and rejects duplicates, so an
  /// opponent must never be handed the name the human typed. Generating after
  /// reading the human's name and skipping any match is what keeps the default
  /// path from failing with a name the player never entered.
  private func playerNames() -> [String] {
    let typed = humanName.trimmingCharacters(in: .whitespacesAndNewlines)
    // Leaving it blank is a normal choice in a solo game, not an error.
    let human = typed.isEmpty ? "You" : typed
    var names = [human]
    var number = 1
    while names.count <= opponentCount {
      let candidate = "Opponent \(number)"
      number += 1
      if candidate.lowercased() != human.lowercased() {
        names.append(candidate)
      }
    }
    return names
  }

  func start() -> Bool {
    var generator = SystemRandomNumberGenerator()
    return start {
      try GameEngine(
        playerNames: playerNames(),
        shufflingWith: &generator
      )
    }
  }

  func start(with deck: Deck) -> Bool {
    start {
      try GameEngine(playerNames: playerNames(), deck: deck)
    }
  }

  private func start(_ makeEngine: () throws -> GameEngine) -> Bool {
    do {
      var engine = try makeEngine()
      let events = try engine.send(.startRound)
      self.engine = engine
      commandError = nil
      let messages = events.compactMap { message(for: $0, in: engine.state) }
      if let actingPlayerID, !messages.isEmpty {
        turnOutcome = TurnOutcome(playerID: actingPlayerID, messages: messages)
      } else {
        turnOutcome = nil
      }
      inputVersion += 1
      scheduleOpponentTurn()
      return true
    } catch let error as GameRuleError {
      setupError = message(for: error)
      return false
    } catch {
      setupError = "The game couldn't start."
      return false
    }
  }

  func hit(_ playerID: PlayerID, inputVersion: Int) {
    guard actingPlayerID == playerID, playerID == humanPlayerID else {
      return
    }
    send(.hit(playerID), outcomeOwnerID: playerID, inputVersion: inputVersion)
  }

  func stay(_ playerID: PlayerID, inputVersion: Int) {
    guard actingPlayerID == playerID, playerID == humanPlayerID else {
      return
    }
    send(.stay(playerID), outcomeOwnerID: playerID, inputVersion: inputVersion)
  }

  func chooseActionTarget(
    cardID: CardID,
    targetPlayerID: PlayerID,
    inputVersion: Int
  ) {
    guard let sourcePlayerID = actingPlayerID, sourcePlayerID == humanPlayerID else {
      return
    }
    send(
      .chooseActionTarget(cardID: cardID, targetPlayerID: targetPlayerID),
      outcomeOwnerID: sourcePlayerID,
      inputVersion: inputVersion
    )
  }

  func startNextRound(inputVersion: Int) {
    send(.startNextRound, outcomeOwnerID: nil, inputVersion: inputVersion)
  }

  /// The command for the acting seat when that seat is computer driven.
  /// Synchronous and free of timing, so tests drive a whole game in a loop
  /// without touching `Task`.
  func opponentCommandIfNeeded() -> GameCommand? {
    guard let state, let seat = actingPlayerID, seat != humanPlayerID else {
      return nil
    }
    var generator = SystemRandomNumberGenerator()
    return opponentCommand(for: state, seat: seat, using: &generator)
  }

  /// Plays one computer decision. Returns false when the acting seat is the
  /// human or there is nothing to do.
  @discardableResult
  func playOpponentTurnIfNeeded() -> Bool {
    guard let command = opponentCommandIfNeeded(), let seat = actingPlayerID else {
      return false
    }
    send(command, outcomeOwnerID: seat, inputVersion: inputVersion)
    return true
  }

  /// Schedules the acting computer seat's turn after a pause, so a human can
  /// follow what happened. One-shot: nothing loops, and the display returns to
  /// rest between decisions.
  private func scheduleOpponentTurn() {
    opponentTask?.cancel()
    opponentTask = nil
    guard let seat = actingPlayerID, seat != humanPlayerID else {
      return
    }

    let version = inputVersion
    let low = turnDelayRange.lowerBound
    let high = turnDelayRange.upperBound
    let delay = low == high ? low : low + (high - low) * Double.random(in: 0...1)

    opponentTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled, let self, self.inputVersion == version else {
        return
      }
      self.playOpponentTurnIfNeeded()
    }
  }

  func resetGame() {
    opponentTask?.cancel()
    opponentTask = nil
    engine = nil
    commandError = nil
    turnOutcome = nil
  }

  private func send(
    _ command: GameCommand,
    outcomeOwnerID: PlayerID?,
    inputVersion: Int
  ) {
    guard inputVersion == self.inputVersion, var engine else {
      return
    }

    let commandMessage = message(for: command, in: engine.state)
    do {
      let events = try engine.send(command)
      self.engine = engine
      self.inputVersion += 1
      commandError = nil

      if let outcomeOwnerID {
        let messages =
          [commandMessage].compactMap { $0 }
          + events.compactMap { message(for: $0, in: engine.state) }
        let outcomeMessages = messages.isEmpty ? ["Action complete."] : messages
        turnOutcome = TurnOutcome(
          playerID: outcomeOwnerID,
          messages: outcomeMessages
        )
        AccessibilityNotification.Announcement(
          outcomeMessages.joined(separator: " ")
        ).post()
      } else {
        let messages = events.compactMap { message(for: $0, in: engine.state) }
        if command == .startNextRound,
          let actingPlayerID,
          !messages.isEmpty
        {
          turnOutcome = TurnOutcome(playerID: actingPlayerID, messages: messages)
        }
        announceCurrentView()
      }
      scheduleOpponentTurn()
    } catch {
      self.inputVersion += 1
      commandError = "That action is no longer available."
      AccessibilityNotification.Announcement(commandError ?? "Action unavailable.").post()
      // Bumping inputVersion above invalidated any sleeping task, so this must
      // reschedule or a computer seat on turn hangs the game permanently.
      scheduleOpponentTurn()
    }
  }

  private func announceCurrentView() {
    // Both parts, in one announcement. turnOutcome is never nil after start(),
    // so announcing only the outcome would never say whose turn it is.
    let parts = [turnOutcome?.messages.joined(separator: " "), turnPrompt]
      .compactMap { $0 }
    guard !parts.isEmpty else {
      return
    }
    AccessibilityNotification.Announcement(parts.joined(separator: " ")).post()
  }

  private func message(for command: GameCommand, in state: GameState) -> String? {
    guard case .chooseActionTarget(_, let targetPlayerID) = command,
      case .awaitingAction(let decision) = state.phase,
      decision.card.kind != .action(.secondChance)
    else {
      return nil
    }
    return "\(decision.card.displayName) assigned to \(state.playerName(for: targetPlayerID))."
  }

  private func message(for event: GameEvent, in state: GameState) -> String? {
    switch event {
    case .roundStarted(let roundNumber, _):
      "Round \(roundNumber) started."
    case .deckRecycled:
      "The discard pile was reshuffled."
    case .cardDrawn(let playerID, let card):
      "\(state.playerName(for: playerID)) drew \(card.displayName)."
    case .actionDiscardedWithoutTarget(let card):
      "\(card.displayName) was discarded."
    case .secondChanceGranted(let playerID, _):
      "\(state.playerName(for: playerID)) received Second Chance."
    case .secondChanceUsed(let playerID, _, _):
      "Second Chance kept \(state.playerName(for: playerID)) in the round."
    case .playerStayed(let playerID):
      "\(state.playerName(for: playerID)) stayed."
    case .playerBusted(let playerID, _):
      "\(state.playerName(for: playerID)) busted."
    case .flipSeven(let playerID):
      "\(state.playerName(for: playerID)) revealed seven different number cards."
    case .actionRequiresResolution:
      nil
    case .roundEnded(let summary):
      "Round \(summary.roundNumber) ended."
    case .gameEnded(let result):
      "\(winnerNames(for: result, in: state)) won with \(result.winningScore) points."
    }
  }

  private func winnerNames(for result: GameResult, in state: GameState) -> String {
    result.winnerIDs.map { state.playerName(for: $0) }.joined(separator: ", ")
  }

  private func message(for error: GameRuleError) -> String {
    switch error {
    case .invalidPlayerCount:
      "Choose between \(Ruleset.minimumPlayerCount - 1) and "
        + "\(Ruleset.maximumPlayerCount - 1) opponents."
    case .emptyPlayerName:
      "Enter your name."
    case .duplicatePlayerName(let name):
      "\(name) is used more than once."
    default:
      "The game couldn't start."
    }
  }
}
