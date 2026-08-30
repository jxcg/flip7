import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class GameSession {
  struct PlayerDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
  }

  var playerDrafts = (1...Ruleset.minimumPlayerCount).map {
    PlayerDraft(name: "Player \($0)")
  } {
    didSet {
      setupError = nil
    }
  }
  private(set) var setupError: String?
  var revealedPlayerID: PlayerID?
  private(set) var engine: GameEngine?

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
    return state.players.first { $0.id == actingPlayerID }?.name
  }

  var isActingPlayerRevealed: Bool {
    guard let actingPlayerID else {
      return false
    }
    return revealedPlayerID == actingPlayerID
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
    guard canRemovePlayer,
      playerDrafts.count - offsets.count >= Ruleset.minimumPlayerCount
    else {
      return
    }
    playerDrafts.remove(atOffsets: offsets)
  }

  func movePlayers(from offsets: IndexSet, to destination: Int) {
    playerDrafts.move(fromOffsets: offsets, toOffset: destination)
  }

  func start() -> Bool {
    var generator = SystemRandomNumberGenerator()

    do {
      var engine = try GameEngine(
        playerNames: playerDrafts.map(\.name),
        shufflingWith: &generator
      )
      try engine.send(.startRound, using: &generator)
      self.engine = engine
      setupError = nil
      revealedPlayerID = nil
      return true
    } catch let error as GameRuleError {
      setupError = message(for: error)
      return false
    } catch {
      setupError = "The game couldn't start."
      return false
    }
  }

  func revealForCurrentPlayer() {
    revealedPlayerID = actingPlayerID
  }

  func resetGame() {
    engine = nil
    revealedPlayerID = nil
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
