import Testing

@testable import Flip7Core

@Test("Player names and dealer seat are validated")
func validatesSetup() {
  expectGameError(.invalidPlayerCount(2)) {
    _ = try GameEngine(
      playerNames: ["Ada", "Ben"],
      deck: testDeck([])
    )
  }
  expectGameError(.invalidPlayerCount(10)) {
    _ = try GameEngine(
      playerNames: (1...10).map { "Player \($0)" },
      deck: testDeck([])
    )
  }
  expectGameError(.emptyPlayerName(index: 1)) {
    _ = try GameEngine(
      playerNames: ["Ada", " \n ", "Cy"],
      deck: testDeck([])
    )
  }
  expectGameError(.duplicatePlayerName("ada")) {
    _ = try GameEngine(
      playerNames: ["Ada", "Ben", " ada "],
      deck: testDeck([])
    )
  }
  expectGameError(.invalidDealerIndex(3)) {
    _ = try GameEngine(
      playerNames: testNames,
      deck: testDeck([]),
      dealerIndex: 3
    )
  }
}

@Test("Opening deal starts left of the dealer and the dealer acts last")
func openingDealOrder() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.three),
      .number(.four),
      .scoreModifier(.additive(.two)),
    ]),
    dealerIndex: 0
  )

  let events = try engine.send(.startRound)

  #expect(drawnPlayerIDs(in: events) == [player(1), player(2), player(0)])
  #expect(engine.state.players[1].roundCards.numberValues == [.three])
  #expect(engine.state.players[2].roundCards.numberValues == [.four])
  #expect(engine.state.players[0].roundCards.scoreModifiers == [.additive(.two)])
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("Hit and stay rotate through active players")
func turnRotation() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
    ])
  )
  try engine.send(.startRound)

  try engine.send(.hit(player(1)))
  #expect(engine.state.phase == .awaitingTurn(player(2)))

  try engine.send(.stay(player(2)))
  #expect(engine.state.phase == .awaitingTurn(player(0)))

  try engine.send(.hit(player(0)))
  #expect(engine.state.phase == .awaitingTurn(player(1)))

  try engine.send(.stay(player(1)))
  #expect(engine.state.phase == .awaitingTurn(player(0)))
}

@Test("A duplicate number busts the player and scores zero")
func duplicateBust() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.five),
      .number(.two),
      .number(.three),
      .number(.five),
    ])
  )
  try engine.send(.startRound)

  let bustEvents = try engine.send(.hit(player(1)))

  #expect(engine.state.players[1].status == .busted)
  #expect(engine.state.players[1].roundCards.numberValues == [.five, .five])
  #expect(engine.state.players[1].roundScore.total == 0)
  #expect(engine.state.phase == .awaitingTurn(player(2)))
  #expect(
    bustEvents.contains {
      if case .playerBusted(player(1), _) = $0 { true } else { false }
    }
  )

  try engine.send(.stay(player(2)))
  try engine.send(.stay(player(0)))

  guard case .roundComplete(let summary) = engine.state.phase else {
    Issue.record("Expected a completed round")
    return
  }
  #expect(summary.reason == .allPlayersInactive)
  #expect(engine.state.players[1].bankedScore == 0)
  #expect(engine.state.players[2].bankedScore == 2)
  #expect(engine.state.players[0].bankedScore == 3)
}

@Test("Second Chance consumes itself and the duplicate without busting")
func secondChanceHook() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.secondChance),
      .number(.two),
      .number(.three),
      .number(.five),
      .number(.five),
    ])
  )
  try engine.send(.startRound)
  #expect(engine.state.players[1].secondChance?.kind == .action(.secondChance))

  try engine.send(.hit(player(1)))
  try engine.send(.stay(player(2)))
  try engine.send(.stay(player(0)))
  let saveEvents = try engine.send(.hit(player(1)))

  #expect(engine.state.players[1].status == .active)
  #expect(engine.state.players[1].secondChance == nil)
  #expect(engine.state.players[1].roundCards.numberValues == [.five])
  #expect(engine.state.deck.discardedCount == 2)
  #expect(engine.state.phase == .awaitingTurn(player(1)))
  #expect(
    saveEvents.contains {
      if case .secondChanceUsed(player(1), _, _) = $0 { true } else { false }
    }
  )
}

@Test("A second Second Chance is discarded when no active player can take it")
func secondChanceWithoutEligibleTargetIsDiscarded() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.secondChance),
      .number(.two),
      .number(.three),
      .number(.one),
      .action(.secondChance),
    ])
  )
  try engine.send(.startRound)

  let originalSecondChance = engine.state.players[1].secondChance
  try engine.send(.hit(player(1)))
  try engine.send(.stay(player(2)))
  try engine.send(.stay(player(0)))
  try engine.send(.hit(player(1)))

  #expect(engine.state.players[1].secondChance == originalSecondChance)
  #expect(engine.state.deck.discardedCount == 1)
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("An unresolved action pauses with its exact opening-deal continuation")
func actionCreatesPendingDecision() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.freeze),
      .number(.two),
      .number(.three),
    ])
  )

  let events = try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending action decision")
    return
  }
  #expect(decision.sourcePlayerID == player(1))
  #expect(decision.card.kind == .action(.freeze))
  #expect(decision.continuation == .openingDeal(nextOffset: 1))
  #expect(engine.state.deck.remainingCount == 2)
  #expect(events.last == .actionRequiresResolution(decision))
}

@Test("Seven unique numbers end the round and bank every eligible score")
func flipSevenEndsRound() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.zero),
      .number(.ten),
      .number(.eleven),
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
      .number(.six),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))
  try engine.send(.stay(player(2)))
  try engine.send(.stay(player(0)))
  try engine.send(.hit(player(1)))
  try engine.send(.hit(player(1)))
  try engine.send(.hit(player(1)))
  try engine.send(.hit(player(1)))
  let finalEvents = try engine.send(.hit(player(1)))

  guard case .roundComplete(let summary) = engine.state.phase else {
    Issue.record("Expected Flip Seven to complete the round")
    return
  }
  #expect(summary.reason == .flipSeven(player(1)))
  #expect(engine.state.players[1].bankedScore == 36)
  #expect(engine.state.players[2].bankedScore == 10)
  #expect(engine.state.players[0].bankedScore == 11)
  #expect(finalEvents.contains(.flipSeven(player(1))))
}

@Test("A new round rotates the dealer and retains the remaining draw pile")
func nextRoundRotation() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
      .number(.six),
    ])
  )
  try engine.send(.startRound)
  try stayEveryone(in: &engine)

  try engine.send(.startNextRound)

  #expect(engine.state.roundNumber == 2)
  #expect(engine.state.dealerID == player(1))
  #expect(engine.state.phase == .awaitingTurn(player(2)))
  #expect(engine.state.players[2].roundCards.numberValues == [.four])
  #expect(engine.state.players[0].roundCards.numberValues == [.five])
  #expect(engine.state.players[1].roundCards.numberValues == [.six])
  #expect(engine.state.deck.discardedCount == 3)
}

@Test("Discards reshuffle only when the next round exhausts the draw pile")
func gameReshufflesOnExhaustion() throws {
  let originalDeck = testDeck([
    .number(.one),
    .number(.two),
    .number(.three),
  ])
  var engine = try GameEngine(playerNames: testNames, deck: originalDeck)
  var generator = SeededGameGenerator(seed: 123)
  try engine.send(.startRound, using: &generator)
  try stayEveryone(in: &engine, using: &generator)

  let events = try engine.send(.startNextRound, using: &generator)

  #expect(events.filter { $0 == .deckRecycled }.count == 1)
  #expect(engine.state.roundNumber == 2)
  #expect(engine.state.deck.remainingCount == 0)
  #expect(engine.state.deck.discardedCount == 0)
  let currentCardIDs = Set(engine.state.players.flatMap { $0.roundCards.cards }.map(\.id))
  #expect(currentCardIDs == Set(originalDeck.drawPile.map(\.id)))
}

@Test("Game end selects the highest total and preserves ties")
func gameVictoryAndTie() throws {
  var tiedGame = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.one),
      .number(.one),
    ]),
    dealerIndex: 0,
    startingScores: [199, 0, 199]
  )
  try tiedGame.send(.startRound)
  try stayEveryone(in: &tiedGame)

  guard case .gameComplete(let tiedResult) = tiedGame.state.phase else {
    Issue.record("Expected a tied game result")
    return
  }
  #expect(tiedResult.winningScore == 200)
  #expect(tiedResult.winnerIDs == [player(0), player(2)])

  var highestGame = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.ten),
      .number(.eleven),
      .number(.one),
    ]),
    dealerIndex: 0,
    startingScores: [199, 195, 190]
  )
  try highestGame.send(.startRound)
  try stayEveryone(in: &highestGame)

  guard case .gameComplete(let highestResult) = highestGame.state.phase else {
    Issue.record("Expected a completed game")
    return
  }
  #expect(highestResult.winningScore == 205)
  #expect(highestResult.winnerIDs == [player(1)])
}

@Test("Invalid commands are rejected without mutating state")
func invalidCommandsAreTransactional() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
    ])
  )
  let initialState = engine.state

  expectGameError(.commandNotAllowed) {
    try engine.send(.hit(player(1)))
  }
  #expect(engine.state == initialState)

  try engine.send(.startRound)
  let startedState = engine.state
  expectGameError(.wrongPlayer(expected: player(1), actual: player(0))) {
    try engine.send(.hit(player(0)))
  }
  #expect(engine.state == startedState)

  expectGameError(.commandNotAllowed) {
    try engine.send(.startRound)
  }
  #expect(engine.state == startedState)
}

@Test("Deck exhaustion rolls back a partially attempted deal")
func deckExhaustionIsTransactional() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
    ])
  )
  let initialState = engine.state

  expectGameError(.deckExhausted) {
    try engine.send(.startRound)
  }

  #expect(engine.state == initialState)
}

private let testNames = ["Ada", "Ben", "Cy"]

private func player(_ index: Int) -> PlayerID {
  PlayerID(rawValue: index)
}

private func testDeck(_ kinds: [CardKind]) -> Deck {
  Deck(
    drawPile: kinds.enumerated().map { index, kind in
      GameCard(id: CardID(rawValue: index), kind: kind)
    }
  )
}

private func drawnPlayerIDs(in events: [GameEvent]) -> [PlayerID] {
  events.compactMap { event in
    if case .cardDrawn(let playerID, _) = event {
      playerID
    } else {
      nil
    }
  }
}

private func stayEveryone(in engine: inout GameEngine) throws {
  while let currentPlayerID = engine.state.currentPlayerID {
    try engine.send(.stay(currentPlayerID))
  }
}

private func stayEveryone<R: RandomNumberGenerator>(
  in engine: inout GameEngine,
  using generator: inout R
) throws {
  while let currentPlayerID = engine.state.currentPlayerID {
    try engine.send(.stay(currentPlayerID), using: &generator)
  }
}

private func expectGameError(
  _ expectedError: GameRuleError,
  performing operation: () throws -> Void
) {
  do {
    try operation()
    Issue.record("Expected \(expectedError), but the operation succeeded")
  } catch let error as GameRuleError {
    #expect(error == expectedError)
  } catch {
    Issue.record("Expected \(expectedError), but received \(error)")
  }
}

private struct SeededGameGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
    return state
  }
}
