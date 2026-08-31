import Flip7Core
import Testing

@testable import Flip7Session

@MainActor
@Test("A seeded solo game reaches a final result with no timing")
func soloGameCompletes() throws {
  let session = GameSession()
  session.humanName = "Josh"
  session.opponentCount = 3
  #expect(session.start(with: .canonical))
  #expect(session.setupError == nil)

  var sawOpponentTurn = false
  for _ in 0..<5_000 {
    let state = try #require(session.state)
    if case .gameComplete(let result) = state.phase {
      #expect(!result.winnerIDs.isEmpty)
      #expect(result.winningScore >= Ruleset.targetScore)
      #expect(sawOpponentTurn)
      return
    }
    if case .roundComplete = state.phase {
      session.startNextRound(inputVersion: session.inputVersion)
      continue
    }
    if session.playOpponentTurnIfNeeded() {
      sawOpponentTurn = true
      continue
    }
    // The human plays a fixed, boring strategy so this stays a test of the
    // driver rather than of human choices.
    let seat = try #require(session.actingPlayerID)
    #expect(seat == session.humanPlayerID)
    if case .awaitingAction(let decision) = state.phase {
      let target = try #require(decision.legalTargetIDs.first)
      session.chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: target,
        inputVersion: session.inputVersion
      )
    } else if state.players.first(where: { $0.id == seat })?.hasCardInFront == true {
      session.stay(seat, inputVersion: session.inputVersion)
    } else {
      session.hit(seat, inputVersion: session.inputVersion)
    }
  }
  Issue.record("The seeded solo game did not finish")
}

/// Plays computer turns until the human is the acting seat. The first turn of a
/// round belongs to the seat left of the dealer, which is not always the human.
@MainActor
private func advanceToHumanTurn(_ session: GameSession) {
  for _ in 0..<200 where session.actingPlayerID != session.humanPlayerID {
    if !session.playOpponentTurnIfNeeded() { return }
  }
}

@MainActor
@Test("The human cannot act for a computer seat")
func humanCannotPlayComputerSeats() throws {
  let session = GameSession()
  session.opponentCount = 2
  #expect(session.start(with: .canonical))

  let seat = try #require(session.actingPlayerID)
  try #require(seat != session.humanPlayerID)

  let before = session.state
  session.hit(seat, inputVersion: session.inputVersion)
  session.stay(seat, inputVersion: session.inputVersion)
  #expect(session.state == before)
}

@MainActor
@Test("A stale input version is rejected without an error")
func staleInputIsRejected() throws {
  let session = GameSession()
  session.opponentCount = 2
  #expect(session.start(with: .canonical))
  advanceToHumanTurn(session)
  let seat = try #require(session.actingPlayerID)
  try #require(seat == session.humanPlayerID)

  let staleVersion = session.inputVersion
  session.hit(seat, inputVersion: staleVersion)
  let stateAfterHit = session.state
  let versionAfterHit = session.inputVersion

  session.hit(seat, inputVersion: staleVersion)
  #expect(session.state == stateAfterHit)
  #expect(session.inputVersion == versionAfterHit)
  #expect(session.commandError == nil)
}

@MainActor
@Test("Starting with the default name succeeds")
func defaultNameStartsCleanly() throws {
  let session = GameSession()
  #expect(session.start(with: .canonical))
  #expect(session.setupError == nil)
  let names = try #require(session.state).players.map(\.name)
  #expect(Set(names.map { $0.lowercased() }).count == names.count)
}
