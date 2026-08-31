import Testing

@testable import Flip7Core

private func seat(_ number: Int) -> PlayerID {
  PlayerID(rawValue: number)
}

private func numberCards(_ values: [NumberValue], startingAt first: Int) -> [GameCard] {
  values.enumerated().map { offset, value in
    GameCard(id: CardID(rawValue: first + offset), kind: .number(value))
  }
}

/// Builds a state where `seat(0)` is on turn holding `held`, with exactly
/// `pile` left to draw. `let` because the engine is only read, and the suite
/// builds with warnings as errors.
private func turnState(held: [NumberValue], pile: [NumberValue]) throws -> GameState {
  let engine = try GameEngine(
    playerNames: ["A", "B", "C"],
    deck: Deck(drawPile: numberCards(pile, startingAt: 900))
  )
  var state = engine.state
  state.players[0].roundCards = RoundCards(cards: numberCards(held, startingAt: 800))
  state.phase = .awaitingTurn(seat(0))
  return state
}

/// Puts `seat(0)` on an action decision for `card` with the given legal targets.
private func actionState(
  card: ActionCard,
  targets: [PlayerID],
  configure: (inout GameState) -> Void = { _ in }
) throws -> GameState {
  let engine = try GameEngine(playerNames: ["A", "B", "C"], deck: .canonical)
  var state = engine.state
  configure(&state)
  state.phase = .awaitingAction(
    PendingActionDecision(
      sourcePlayerID: seat(0),
      card: GameCard(id: CardID(rawValue: 600), kind: .action(card)),
      legalTargetIDs: targets,
      queuedActions: [],
      forcedDraw: nil,
      continuation: .advanceTurn(after: seat(0))
    )
  )
  return state
}

@Test("An empty hand always hits")
func emptyHandHits() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try turnState(held: [], pile: [.five, .six, .seven])
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .hit(seat(0)))
}

@Test("A hand stays when every remaining card would bust it")
func certainBustStays() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try turnState(held: [.five, .six], pile: [.five, .six, .five])
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .stay(seat(0)))
}

@Test("Holding Second Chance makes the next draw free, so it hits")
func secondChanceHits() throws {
  var generator = SeededGenerator(seed: 1)
  var state = try turnState(held: [.five, .six], pile: [.five, .six, .five])
  state.players[0].secondChance = GameCard(
    id: CardID(rawValue: 700),
    kind: .action(.secondChance)
  )
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .hit(seat(0)))
}

@Test("A seat with no decision to make returns nil")
func noDecisionReturnsNil() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try turnState(held: [], pile: [.five])
  #expect(opponentCommand(for: state, seat: seat(1), using: &generator) == nil)
}
@Test("Freeze denies a Flip 7 chase rather than punishing the leader")
func freezeTargetsTheFlipSevenChase() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .freeze, targets: [seat(1), seat(2)]) { state in
    // Seat 1 holds a big score in few cards. Freezing banks it for them.
    state.players[1].roundCards = RoundCards(
      cards: numberCards([.twelve, .eleven], startingAt: 500)
    )
    // Seat 2 is five uniques into a Flip 7 run.
    state.players[2].roundCards = RoundCards(
      cards: numberCards([.one, .two, .three, .four, .five], startingAt: 510)
    )
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(2))
  )
}

@Test("Freeze never picks an illegal target")
func freezeStaysLegal() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .freeze, targets: [seat(2)])
  guard
    case .chooseActionTarget(_, let target)? = opponentCommand(
      for: state,
      seat: seat(0),
      using: &generator
    )
  else {
    Issue.record("expected a target choice")
    return
  }
  #expect(target == seat(2))
}

@Test("Flip Three targets the seat most likely to bust")
func flipThreeTargetsTheFullestHand() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .flipThree, targets: [seat(1), seat(2)]) { state in
    state.players[1].roundCards = RoundCards(cards: numberCards([.one], startingAt: 520))
    state.players[2].roundCards = RoundCards(
      cards: numberCards([.one, .two, .three, .four], startingAt: 530)
    )
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(2))
  )
}

@Test("Second Chance is kept when the seat may target itself")
func secondChanceIsKept() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .secondChance, targets: [seat(0), seat(1)])
  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(0))
  )
}

@Test("A Second Chance that cannot be kept goes to whoever it helps least")
func secondChanceGoesToTheSafestOpponent() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .secondChance, targets: [seat(1), seat(2)]) { state in
    state.players[1].roundCards = RoundCards(cards: numberCards([.one], startingAt: 540))
    state.players[2].roundCards = RoundCards(
      cards: numberCards([.one, .two, .three], startingAt: 550)
    )
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(1))
  )
}
