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
