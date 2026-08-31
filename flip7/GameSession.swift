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
  struct PlayerDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
  }

  struct TurnOutcome: Equatable {
    let playerID: PlayerID
    let messages: [String]
  }

  var playerDrafts = (1...Ruleset.minimumPlayerCount).map {
    PlayerDraft(name: "Player \($0)")
  } {
    didSet {
      setupError = nil
    }
  }
  private(set) var setupError: String?
  private(set) var commandError: String?
  private(set) var turnOutcome: TurnOutcome?
  private(set) var inputVersion = 0
  private(set) var engine: GameEngine?

  var state: GameState? {
    engine?.state
  }

  var canAddPlayer: Bool {
    playerDrafts.count < Ruleset.maximumPlayerCount
  }

  var canRemovePlayer: Bool {
    playerDrafts.count > Ruleset.minimumPlayerCount
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

  var actingPlayerName: String? {
    guard let state = engine?.state, let actingPlayerID else {
      return nil
    }
    return state.playerName(for: actingPlayerID)
  }

  func addPlayer() {
    guard canAddPlayer else {
      return
    }

    let names = Set(
      playerDrafts.map {
        $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      })
    var number = 1
    while names.contains("player \(number)") {
      number += 1
    }
    playerDrafts.append(PlayerDraft(name: "Player \(number)"))
  }

  func removePlayers(at offsets: IndexSet) {
    guard playerDrafts.count - offsets.count >= Ruleset.minimumPlayerCount else {
      return
    }
    playerDrafts.remove(atOffsets: offsets)
  }

  func movePlayers(from offsets: IndexSet, to destination: Int) {
    playerDrafts.move(fromOffsets: offsets, toOffset: destination)
  }

  func start() -> Bool {
    var generator = SystemRandomNumberGenerator()
    return start {
      try GameEngine(
        playerNames: playerDrafts.map(\.name),
        shufflingWith: &generator
      )
    }
  }

  func start(with deck: Deck) -> Bool {
    start {
      try GameEngine(playerNames: playerDrafts.map(\.name), deck: deck)
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
    guard actingPlayerID == playerID else {
      return
    }
    send(.hit(playerID), outcomeOwnerID: playerID, inputVersion: inputVersion)
  }

  func stay(_ playerID: PlayerID, inputVersion: Int) {
    guard actingPlayerID == playerID else {
      return
    }
    send(.stay(playerID), outcomeOwnerID: playerID, inputVersion: inputVersion)
  }

  func chooseActionTarget(
    cardID: CardID,
    targetPlayerID: PlayerID,
    inputVersion: Int
  ) {
    guard let sourcePlayerID = actingPlayerID else {
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

  func resetGame() {
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
    } catch {
      self.inputVersion += 1
      commandError = "That action is no longer available."
      AccessibilityNotification.Announcement(commandError ?? "Action unavailable.").post()
    }
  }

  private func announceCurrentView() {
    if let turnOutcome {
      AccessibilityNotification.Announcement(
        turnOutcome.messages.joined(separator: " ")
      ).post()
      return
    }

    guard let state, let actingPlayerName else {
      return
    }

    let message =
      switch state.phase {
      case .awaitingTurn(let playerID):
        if state.players.first(where: { $0.id == playerID })?.hasCardInFront == true {
          "\(actingPlayerName)'s turn. Available actions: Hit or Stay."
        } else {
          "\(actingPlayerName)'s turn. Available action: Hit."
        }
      case .awaitingAction(let decision):
        "\(actingPlayerName) must choose a target for "
          + "\(decision.card.displayName). Available targets: "
          + decision.legalTargetIDs.map { state.playerName(for: $0) }.joined(separator: ", ")
          + "."
      case .waitingToStartRound, .dealingOpeningCards,
        .roundComplete, .gameComplete:
        actingPlayerName
      }
    AccessibilityNotification.Announcement(message).post()
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
      "Add between \(Ruleset.minimumPlayerCount) and \(Ruleset.maximumPlayerCount) players."
    case .emptyPlayerName(let index):
      "Enter a name for Player \(index + 1)."
    case .duplicatePlayerName(let name):
      "\(name) is used more than once."
    default:
      "The game couldn't start."
    }
  }
}
