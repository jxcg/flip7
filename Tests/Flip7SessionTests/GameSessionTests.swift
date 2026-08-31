import Flip7Core
import Testing

@testable import Flip7Session

@MainActor
@Test("A solo game reaches a final result without touching timing")
func soloGameCompletes() throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
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
  Issue.record("The solo game did not finish")
}

/// Plays computer turns until the human is the acting seat. The first turn of a
/// round belongs to the seat left of the dealer, which is not always the human.
@MainActor
private func advanceToHumanTurn(_ session: GameSession) {
  var guardCounter = 0
  while session.actingPlayerID != session.humanPlayerID, guardCounter < 200 {
    guardCounter += 1
    if !session.playOpponentTurnIfNeeded() { return }
  }
}

@MainActor
@Test("The human cannot act for a computer seat")
func humanCannotPlayComputerSeats() throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
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
  session.turnDelayRange = .zero ... .zero
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
  session.turnDelayRange = .zero ... .zero
  #expect(session.start(with: .canonical))
  #expect(session.setupError == nil)
  let names = try #require(session.state).players.map(\.name)
  #expect(Set(names.map { $0.lowercased() }).count == names.count)
}

@MainActor
@Test("The paced driver plays a computer turn, and reset cancels it")
func pacedDriverRunsAndCancels() async throws {
  let session = GameSession()
  // Both bounds zero keeps the suite fast. The randomness never needs
  // reproducing, only switching off.
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 2
  #expect(session.start(with: .canonical))
  try #require(session.actingPlayerID != session.humanPlayerID)

  let versionBefore = session.inputVersion
  await session.opponentTask?.value
  #expect(session.inputVersion > versionBefore)

  session.resetGame()
  #expect(session.opponentTask == nil)
  #expect(session.state == nil)
}

@MainActor
@Test("A rejected command does not strand the computer turn driver")
func rejectedCommandDoesNotStallTheDriver() async throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 2
  #expect(session.start(with: .canonical))
  try #require(session.actingPlayerID != session.humanPlayerID)

  // startNextRound is the one entry point with no seat guard, so the engine
  // rejects it here. The catch path bumps inputVersion, which invalidates any
  // sleeping task, so it must reschedule or the game hangs forever.
  session.startNextRound(inputVersion: session.inputVersion)
  #expect(session.commandError != nil)
  try #require(session.actingPlayerID != session.humanPlayerID)

  // A non-nil task is not enough: a stale one returns without acting. Awaiting
  // it must actually advance the game.
  let versionAtRest = session.inputVersion
  await session.opponentTask?.value
  #expect(
    session.inputVersion > versionAtRest,
    "computer seat on turn and the driver never advanced it"
  )
}

@MainActor
@Test("The turn prompt names the active player and the available actions")
func turnPromptDescribesTheCurrentDecision() throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 2
  #expect(session.start(with: .canonical))

  // A prompt must exist for every acting phase, not only before the first
  // outcome. VoiceOver has nothing else to announce the turn with.
  var sawPrompt = false
  for _ in 0..<400 {
    guard let state = session.state else { break }
    if case .gameComplete = state.phase { break }
    if case .roundComplete = state.phase {
      session.startNextRound(inputVersion: session.inputVersion)
      continue
    }
    let prompt = try #require(session.turnPrompt, "no prompt for phase \(state.phase)")
    #expect(!prompt.isEmpty)
    if let name = session.actingPlayerName {
      #expect(prompt.contains(name))
    }
    sawPrompt = true
    if session.playOpponentTurnIfNeeded() { continue }
    let seat = try #require(session.actingPlayerID)
    if case .awaitingAction(let decision) = state.phase {
      session.chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: try #require(decision.legalTargetIDs.first),
        inputVersion: session.inputVersion
      )
    } else if state.players.first(where: { $0.id == seat })?.hasCardInFront == true {
      session.stay(seat, inputVersion: session.inputVersion)
    } else {
      session.hit(seat, inputVersion: session.inputVersion)
    }
  }
  #expect(sawPrompt)
}

@MainActor
@Test("Controls are only offered on the human's turn")
func controlsOnlyOnHumanTurn() throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 2
  #expect(session.start(with: .canonical))
  try #require(session.actingPlayerID != session.humanPlayerID)
  #expect(!session.isHumanTurn)

  advanceToHumanTurn(session)
  #expect(session.isHumanTurn)
}

@MainActor
@Test("Chained computer turns run through the async driver to a final result")
func chainedAsyncTurnsComplete() async throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 3
  #expect(session.start(with: .canonical))

  for _ in 0..<5_000 {
    guard let state = session.state else { break }
    if case .gameComplete = state.phase { return }
    if case .roundComplete = state.phase {
      session.startNextRound(inputVersion: session.inputVersion)
      continue
    }
    if let task = session.opponentTask {
      // Driven entirely through the async path, never the sync helper.
      await task.value
      continue
    }
    let seat = try #require(session.actingPlayerID)
    try #require(seat == session.humanPlayerID)
    if case .awaitingAction(let decision) = state.phase {
      session.chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: try #require(decision.legalTargetIDs.first),
        inputVersion: session.inputVersion
      )
    } else if state.players.first(where: { $0.id == seat })?.hasCardInFront == true {
      session.stay(seat, inputVersion: session.inputVersion)
    } else {
      session.hit(seat, inputVersion: session.inputVersion)
    }
  }
  Issue.record("the async driver did not reach a final result")
}
