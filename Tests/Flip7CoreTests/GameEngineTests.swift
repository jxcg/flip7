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

@Test("Second Chance belongs to its assigned target")
func secondChanceRedirect() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.secondChance),
      .number(.two),
      .number(.three),
      .number(.one),
      .number(.four),
      .number(.five),
      .action(.secondChance),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))
  try engine.send(.hit(player(2)))
  try engine.send(.hit(player(0)))
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a Second Chance target decision")
    return
  }
  #expect(decision.legalTargetIDs == [player(0), player(2)])

  let pendingState = engine.state
  expectGameError(.commandNotAllowed) {
    try engine.send(
      .chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: player(1)
      )
    )
  }
  #expect(engine.state == pendingState)

  guard let events = resolveAction(decision, on: player(2), in: &engine) else {
    return
  }
  #expect(engine.state.players[1].secondChance?.id == CardID(rawValue: 0))
  #expect(engine.state.players[2].secondChance?.id == CardID(rawValue: 6))
  #expect(events.contains(.secondChanceGranted(playerID: player(2), card: decision.card)))
  #expect(engine.state.phase == .awaitingTurn(player(2)))
}

@Test("Second Chance resumes the remaining Flip Three draws")
func secondChanceRedirectDuringFlipThree() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.secondChance),
      .number(.two),
      .number(.three),
      .number(.one),
      .action(.flipThree),
      .action(.secondChance),
      .number(.four),
      .number(.five),
      .number(.six),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))
  try engine.send(.hit(player(2)))

  guard case .awaitingAction(let flipThreeDecision) = engine.state.phase else {
    Issue.record("Expected a Flip Three target decision")
    return
  }
  guard let flipThreeEvents = resolveAction(
    flipThreeDecision,
    on: player(1),
    in: &engine
  ) else {
    return
  }
  #expect(drawnPlayerIDs(in: flipThreeEvents) == [player(1)])

  guard case .awaitingAction(let secondChanceDecision) = engine.state.phase else {
    Issue.record("Expected a Second Chance target decision")
    return
  }
  #expect(secondChanceDecision.legalTargetIDs == [player(0), player(2)])

  guard let redirectEvents = resolveAction(
    secondChanceDecision,
    on: player(0),
    in: &engine
  ) else {
    return
  }
  #expect(drawnPlayerIDs(in: redirectEvents) == [player(1), player(1)])
  #expect(engine.state.players[0].secondChance?.id == CardID(rawValue: 5))
  #expect(engine.state.players[1].secondChance?.id == CardID(rawValue: 0))
  #expect(engine.state.deck.remainingCount == 1)
  #expect(engine.state.phase == .awaitingTurn(player(0)))
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

@Test(
  "Freeze and Flip Three expose every active target",
  arguments: [ActionCard.freeze, .flipThree]
)
func targetedActionsExposeActivePlayers(_ action: ActionCard) throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(action),
      .number(.two),
      .number(.three),
    ])
  )

  try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending action decision")
    return
  }
  #expect(decision.legalTargetIDs == [player(0), player(1), player(2)])
}

@Test("Freeze skips an undealt target and resumes the opening deal")
func freezeDuringOpeningDeal() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.freeze),
      .number(.two),
      .number(.three),
    ])
  )
  try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Freeze decision")
    return
  }

  let resolutionError: GameRuleError?
  do {
    try engine.send(
      .chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: player(2)
      )
    )
    resolutionError = nil
  } catch let error as GameRuleError {
    resolutionError = error
  }

  #expect(resolutionError == nil)
  guard resolutionError == nil else {
    return
  }
  #expect(engine.state.players[2].status == .frozen)
  #expect(engine.state.players[2].roundCards.cards == [decision.card])
  #expect(engine.state.players[0].roundCards.numberValues == [.two])
  #expect(engine.state.deck.remainingCount == 1)
  #expect(engine.state.deck.discardedCount == 0)
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("Freeze banks its target and resumes after the source player")
func freezeDuringTurn() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .action(.freeze),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Freeze decision")
    return
  }

  let resolutionError: GameRuleError?
  do {
    try engine.send(
      .chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: player(2)
      )
    )
    resolutionError = nil
  } catch let error as GameRuleError {
    resolutionError = error
  }

  #expect(resolutionError == nil)
  guard resolutionError == nil else {
    return
  }
  #expect(engine.state.players[2].status == .frozen)
  #expect(engine.state.players[2].roundCards.cards.last == decision.card)
  #expect(engine.state.phase == .awaitingTurn(player(0)))

  try engine.send(.stay(player(0)))
  try engine.send(.stay(player(1)))

  guard case .roundComplete = engine.state.phase else {
    Issue.record("Expected a completed round")
    return
  }
  #expect(engine.state.players[2].bankedScore == 2)
}

@Test(
  "Flip Three draws three cards before the opening deal resumes",
  arguments: [
    CardKind.scoreModifier(.additive(.two)),
    .action(.secondChance),
  ]
)
func flipThreeDuringOpeningDeal(_ middleCard: CardKind) throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.flipThree),
      .number(.one),
      middleCard,
      .number(.three),
      .number(.four),
      .number(.five),
    ])
  )
  try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(0), in: &engine) else {
    return
  }

  #expect(
    drawnPlayerIDs(in: events)
      == [player(0), player(0), player(0), player(2), player(0)]
  )
  #expect(engine.state.players[0].roundCards.actionCards == [.flipThree])
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("Flip Three resumes a normal turn after three draws")
func flipThreeDuringTurn() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .action(.flipThree),
      .number(.four),
      .number(.five),
      .number(.six),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(0), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(0), player(0), player(0)])
  #expect(engine.state.players[0].roundCards.numberValues == [.three, .four, .five, .six])
  #expect(engine.state.phase == .awaitingTurn(player(2)))
}

@Test("Flip Three stops when its target busts")
func flipThreeStopsOnBust() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.flipThree),
      .number(.five),
      .number(.five),
      .number(.six),
      .number(.seven),
    ])
  )
  try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(0), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(0), player(0), player(2)])
  #expect(engine.state.players[0].status == .busted)
  #expect(engine.state.deck.remainingCount == 1)
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("Flip Three stops when its target completes Flip Seven")
func flipThreeStopsOnFlipSeven() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.ten),
      .number(.eleven),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
      .number(.six),
      .action(.flipThree),
      .number(.seven),
      .number(.eight),
      .number(.nine),
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
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(1), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(1)])
  #expect(engine.state.deck.remainingCount == 2)
  guard case .roundComplete(let summary) = engine.state.phase else {
    Issue.record("Expected Flip Seven to complete the round")
    return
  }
  #expect(summary.reason == .flipSeven(player(1)))
}

@Test(
  "Flip Three finishes its draws before resolving another action",
  arguments: [ActionCard.freeze, .flipThree]
)
func deferredActionWaitsForFlipThreeDraws(_ deferredAction: ActionCard) throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.flipThree),
      .action(deferredAction),
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
    ])
  )
  try engine.send(.startRound)

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(0), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(0), player(0), player(0)])
  guard case .awaitingAction(let deferredDecision) = engine.state.phase else {
    Issue.record("Expected the deferred action decision")
    return
  }
  #expect(deferredDecision.sourcePlayerID == player(0))
  #expect(deferredDecision.card.id == CardID(rawValue: 1))
  #expect(
    engine.state.players.allSatisfy { player in
      !player.roundCards.cards.contains { $0.id == deferredDecision.card.id }
    }
  )
  #expect(events.last == .actionRequiresResolution(deferredDecision))
  #expect(engine.state.deck.remainingCount == 2)
}

@Test("An inactive source assigns deferred actions in reveal order")
func inactiveSourceAssignsDeferredActionsInRevealOrder() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .action(.flipThree),
      .action(.freeze),
      .action(.flipThree),
      .number(.one),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
    ])
  )
  try engine.send(.startRound)

  guard case .awaitingAction(let outerDecision) = engine.state.phase else {
    Issue.record("Expected the first Flip Three decision")
    return
  }
  guard let outerEvents = resolveAction(outerDecision, on: player(0), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: outerEvents) == [player(0), player(0), player(0)])
  guard case .awaitingAction(let freezeDecision) = engine.state.phase else {
    Issue.record("Expected the deferred Freeze decision")
    return
  }
  #expect(freezeDecision.sourcePlayerID == player(0))
  #expect(freezeDecision.card.id == CardID(rawValue: 1))

  let unresolvedState = engine.state
  expectGameError(.commandNotAllowed) {
    try engine.send(.stay(player(0)))
  }
  #expect(engine.state == unresolvedState)

  guard resolveAction(freezeDecision, on: player(0), in: &engine) != nil else {
    return
  }
  guard case .awaitingAction(let innerDecision) = engine.state.phase else {
    Issue.record("Expected the deferred Flip Three decision")
    return
  }
  #expect(innerDecision.sourcePlayerID == player(0))
  #expect(innerDecision.card.id == CardID(rawValue: 2))
  #expect(innerDecision.legalTargetIDs == [player(1), player(2)])

  guard let innerEvents = resolveAction(innerDecision, on: player(1), in: &engine) else {
    return
  }
  #expect(
    drawnPlayerIDs(in: innerEvents)
      == [player(1), player(1), player(1), player(2)]
  )
  #expect(engine.state.players[0].status == .frozen)
  #expect(engine.state.phase == .awaitingTurn(player(1)))
}

@Test("Freezing the final active source discards its remaining queue")
func finalActiveSourceDiscardsRemainingQueue() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.three),
      .action(.flipThree),
      .action(.freeze),
      .action(.flipThree),
      .number(.four),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.stay(player(1)))
  try engine.send(.stay(player(2)))

  try engine.send(.hit(player(0)))
  guard case .awaitingAction(let flipThreeDecision) = engine.state.phase else {
    Issue.record("Expected a Flip Three decision")
    return
  }
  guard resolveAction(flipThreeDecision, on: player(0), in: &engine) != nil else {
    return
  }
  guard case .awaitingAction(let freezeDecision) = engine.state.phase else {
    Issue.record("Expected the queued Freeze decision")
    return
  }

  guard let events = resolveAction(freezeDecision, on: player(0), in: &engine) else {
    return
  }

  #expect(engine.state.deck.discardPile.map(\.id) == [CardID(rawValue: 5)])
  #expect(
    engine.state.players.allSatisfy { player in
      !player.roundCards.cards.contains { $0.id == CardID(rawValue: 5) }
    }
  )
  #expect(
    !events.contains { event in
      if case .actionRequiresResolution = event { true } else { false }
    }
  )
  guard case .roundComplete(let summary) = engine.state.phase else {
    Issue.record("Expected the round to finish")
    return
  }
  #expect(summary.reason == .allPlayersInactive)
  #expect(events.last == .roundEnded(summary))
}

@Test(
  "A bust discards actions deferred during Flip Three",
  arguments: [ActionCard.freeze, .flipThree]
)
func deferredActionsAreDiscardedOnBust(_ deferredAction: ActionCard) throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.two),
      .number(.five),
      .action(.flipThree),
      .action(deferredAction),
      .number(.five),
      .number(.six),
    ])
  )
  try engine.send(.startRound)
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(0), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(0), player(0)])
  #expect(engine.state.deck.discardPile.map(\.id) == [CardID(rawValue: 4)])
  #expect(engine.state.deck.remainingCount == 1)
  #expect(engine.state.players[0].status == .busted)
  #expect(
    engine.state.players.allSatisfy { player in
      !player.roundCards.cards.contains { $0.id == CardID(rawValue: 4) }
    }
  )
  #expect(
    !events.contains { event in
      if case .actionRequiresResolution = event { true } else { false }
    }
  )
  #expect(engine.state.phase == .awaitingTurn(player(2)))
}

@Test(
  "Flip Seven discards actions deferred during Flip Three",
  arguments: [ActionCard.freeze, .flipThree]
)
func deferredActionsAreDiscardedOnFlipSeven(_ deferredAction: ActionCard) throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.one),
      .number(.ten),
      .number(.eleven),
      .number(.two),
      .number(.three),
      .number(.four),
      .number(.five),
      .number(.six),
      .action(.flipThree),
      .action(deferredAction),
      .number(.seven),
      .number(.eight),
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
  try engine.send(.hit(player(1)))

  guard case .awaitingAction(let decision) = engine.state.phase else {
    Issue.record("Expected a pending Flip Three decision")
    return
  }
  guard let events = resolveAction(decision, on: player(1), in: &engine) else {
    return
  }

  #expect(drawnPlayerIDs(in: events) == [player(1), player(1)])
  #expect(engine.state.deck.discardPile.map(\.id) == [CardID(rawValue: 9)])
  #expect(engine.state.deck.remainingCount == 1)
  #expect(
    engine.state.players.allSatisfy { player in
      !player.roundCards.cards.contains { $0.id == CardID(rawValue: 9) }
    }
  )
  #expect(
    !events.contains { event in
      if case .actionRequiresResolution = event { true } else { false }
    }
  )
  guard case .roundComplete(let summary) = engine.state.phase else {
    Issue.record("Expected Flip Seven to complete the round")
    return
  }
  #expect(summary.reason == .flipSeven(player(1)))
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

@Test("Tied leaders continue until one player leads")
func tiedLeadersContinueUntilUniqueWinner() throws {
  var engine = try GameEngine(
    playerNames: testNames,
    deck: testDeck([
      .number(.two),
      .number(.one),
      .number(.two),
      .number(.four),
      .number(.three),
      .number(.three),
      .number(.four),
      .number(.four),
      .number(.twelve),
    ]),
    dealerIndex: 0,
    startingScores: [198, 198, 191]
  )
  try engine.send(.startRound)
  let firstTieEvents = try stayEveryone(in: &engine)

  guard case .roundComplete(let firstTie) = engine.state.phase else {
    Issue.record("Expected the tied game to continue")
    return
  }
  #expect(engine.state.players.map(\.bankedScore) == [200, 200, 192])
  #expect(firstTie.nextDealerID == player(1))
  #expect(gameEndedCount(in: firstTieEvents) == 0)

  try engine.send(.startNextRound)
  #expect(engine.state.roundNumber == 2)
  #expect(engine.state.dealerID == player(1))
  #expect(engine.state.phase == .awaitingTurn(player(2)))
  let secondTieEvents = try stayEveryone(in: &engine)

  guard case .roundComplete(let secondTie) = engine.state.phase else {
    Issue.record("Expected the persistent tie to continue")
    return
  }
  #expect(engine.state.players.map(\.bankedScore) == [203, 203, 196])
  #expect(secondTie.nextDealerID == player(2))
  #expect(gameEndedCount(in: secondTieEvents) == 0)

  try engine.send(.startNextRound)
  #expect(engine.state.roundNumber == 3)
  #expect(engine.state.dealerID == player(2))
  #expect(engine.state.phase == .awaitingTurn(player(0)))
  let winningEvents = try stayEveryone(in: &engine)

  guard case .gameComplete(let result) = engine.state.phase else {
    Issue.record("Expected one winner")
    return
  }
  #expect(engine.state.players.map(\.bankedScore) == [207, 207, 208])
  #expect(result.winnerIDs == [player(2)])
  #expect(result.winningScore == 208)
  #expect(gameEndedCount(in: winningEvents) == 1)
}

@Test("A unique highest score ends the game")
func uniqueHighestScoreEndsGame() throws {
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

private func gameEndedCount(in events: [GameEvent]) -> Int {
  events.count { event in
    if case .gameEnded = event { true } else { false }
  }
}

private func resolveAction(
  _ decision: PendingActionDecision,
  on targetPlayerID: PlayerID,
  in engine: inout GameEngine
) -> [GameEvent]? {
  do {
    return try engine.send(
      .chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: targetPlayerID
      )
    )
  } catch {
    Issue.record("Expected the action to resolve, but received \(error)")
    return nil
  }
}

@discardableResult
private func stayEveryone(in engine: inout GameEngine) throws -> [GameEvent] {
  var events: [GameEvent] = []
  while let currentPlayerID = engine.state.currentPlayerID {
    events = try engine.send(.stay(currentPlayerID))
  }
  return events
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
