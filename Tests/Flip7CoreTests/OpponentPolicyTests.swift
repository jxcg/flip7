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

@Test("A Second Chance absorbs the duplicate risk, so a hand with upside hits")
func secondChanceHits() throws {
  var generator = SeededGenerator(seed: 1)
  // Two of three cards would bust an unshielded hand, so it would stay.
  var state = try turnState(held: [.five, .six], pile: [.five, .six, .nine])
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .stay(seat(0)))

  state.players[0].secondChance = GameCard(
    id: CardID(rawValue: 700),
    kind: .action(.secondChance)
  )
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .hit(seat(0)))
}

@Test("A Second Chance is not spent on a draw that cannot gain anything")
func secondChanceIsNotSpentForNothing() throws {
  var generator = SeededGenerator(seed: 1)
  var state = try turnState(held: [.five, .six], pile: [.five, .six, .five])
  state.players[0].secondChance = GameCard(
    id: CardID(rawValue: 700),
    kind: .action(.secondChance)
  )
  // Every remaining card is a duplicate, so hitting burns the shield for zero.
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .stay(seat(0)))
}

@Test("A round score that would win the game is banked rather than grown")
func winningScoreIsBanked() throws {
  var generator = SeededGenerator(seed: 1)
  var state = try turnState(held: [.one], pile: [.nine, .eight, .seven])
  state.players[0].bankedScore = Ruleset.targetScore
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .stay(seat(0)))
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

@Test("The engine never offers a seat its own Second Chance")
func secondChanceIsNeverSelfLegal() throws {
  // GameEngine auto-keeps a drawn Second Chance when the seat holds none, so
  // targeting is reached only when it already holds one, and legalTargetIDs
  // excludes every holder. A self-targeting policy branch would be dead code.
  // A Second Chance decision is rare, roughly once per six games, so this
  // probes several seeded games rather than one.
  var decisions = 0
  for seed in UInt64(1)...30 {
    var generator = SeededGenerator(seed: seed)
    var engine = try GameEngine(playerNames: ["A", "B", "C"], shufflingWith: &generator)
    _ = try engine.send(.startRound)

    for _ in 0..<3_000 {
      if case .gameComplete = engine.state.phase { break }
      if case .roundComplete = engine.state.phase {
        _ = try engine.send(.startNextRound)
        continue
      }
      if case .awaitingAction(let decision) = engine.state.phase,
        decision.card.kind == .action(.secondChance)
      {
        decisions += 1
        #expect(!decision.legalTargetIDs.contains(decision.sourcePlayerID))
      }
      let actingSeat: PlayerID? =
        switch engine.state.phase {
        case .awaitingTurn(let id): id
        case .awaitingAction(let decision): decision.sourcePlayerID
        default: nil
        }
      guard let actingSeat,
        let command = opponentCommand(for: engine.state, seat: actingSeat, using: &generator)
      else { break }
      _ = try engine.send(command)
    }
  }
  #expect(decisions > 0, "the probe never saw a Second Chance decision")
}

@Test("Freeze and Flip Three spare the acting seat when anyone else is legal")
func actionsAvoidTheActingSeat() throws {
  // legalTargetIDs for these cards is every active player, which always
  // includes the seat holding the card. Ranking on harm without excluding self
  // makes a seat that has been drawing hand itself the punishment.
  for card in [ActionCard.freeze, .flipThree] {
    var generator = SeededGenerator(seed: 1)
    let state = try actionState(card: card, targets: [seat(0), seat(1), seat(2)]) { state in
      state.players[0].roundCards = RoundCards(
        cards: numberCards([.one, .two, .three, .four, .five], startingAt: 560)
      )
      state.players[1].roundCards = RoundCards(cards: numberCards([.one], startingAt: 570))
      state.players[2].roundCards = RoundCards(cards: numberCards([.two], startingAt: 580))
    }
    guard
      case .chooseActionTarget(_, let target)? = opponentCommand(
        for: state, seat: seat(0), using: &generator)
    else {
      Issue.record("expected a target choice for \(card)")
      return
    }
    #expect(target != seat(0), "\(card) targeted the acting seat")
  }
}

@Test("An action targets the acting seat when it is the only legal target")
func actionsTargetSelfWhenAlone() throws {
  var generator = SeededGenerator(seed: 1)
  let state = try actionState(card: .flipThree, targets: [seat(0)])
  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(0))
  )
}

@Test("Tied targets vary with the generator rather than always picking one")
func tiedTargetsVaryWithTheGenerator() throws {
  var chosen: Set<PlayerID> = []
  for seed in UInt64(1)...40 {
    var generator = SeededGenerator(seed: seed)
    // Seats 1 and 2 are identical, so the tie-break decides.
    let state = try actionState(card: .freeze, targets: [seat(1), seat(2)])
    if case .chooseActionTarget(_, let target)? = opponentCommand(
      for: state, seat: seat(0), using: &generator)
    {
      chosen.insert(target)
    }
  }
  #expect(chosen == [seat(1), seat(2)])
}

@Test("A Second Chance that cannot be kept goes to whoever it helps least")
func secondChanceGoesToTheSafestOpponent() throws {
  var generator = SeededGenerator(seed: 1)
  // The answer is deliberately not first in legalTargetIDs, so a policy that
  // simply returned candidates.first would fail.
  let state = try actionState(card: .secondChance, targets: [seat(1), seat(2)]) { state in
    state.players[1].roundCards = RoundCards(
      cards: numberCards([.one, .two, .three], startingAt: 540)
    )
    state.players[2].roundCards = RoundCards(cards: numberCards([.one], startingAt: 550))
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(2))
  )
}
@Test("The policy ignores draw order, so it cannot peek at the next card")
func fairnessIgnoresDrawOrder() throws {
  // Same remaining multiset, deliberately different top card: one would bust the
  // seat, one is safe. Constructed rather than shuffled, because a shuffle that
  // happened to preserve the top card would pass while proving nothing.
  let busting = GameCard(id: CardID(rawValue: 300), kind: .number(.five))
  let safe = GameCard(id: CardID(rawValue: 301), kind: .number(.nine))
  let filler = numberCards(Array(repeating: .nine, count: 20), startingAt: 400)

  func command(topCard first: GameCard, then second: GameCard) throws -> GameCommand? {
    let engine = try GameEngine(
      playerNames: ["A", "B", "C"],
      deck: Deck(drawPile: [first, second] + filler)
    )
    var state = engine.state
    state.players[0].roundCards = RoundCards(cards: numberCards([.five], startingAt: 200))
    state.phase = .awaitingTurn(seat(0))
    var generator = SeededGenerator(seed: 1)
    return opponentCommand(for: state, seat: seat(0), using: &generator)
  }

  #expect(try command(topCard: busting, then: safe) == command(topCard: safe, then: busting))
}

@Test("The policy is deterministic for a given state and seed")
func policyIsDeterministic() throws {
  // A tied action decision, so the generator is actually consulted.
  let state = try actionState(card: .freeze, targets: [seat(1), seat(2)])
  var first = SeededGenerator(seed: 42)
  var second = SeededGenerator(seed: 42)
  #expect(
    opponentCommand(for: state, seat: seat(0), using: &first)
      == opponentCommand(for: state, seat: seat(0), using: &second)
  )
}

@Test("Every command the policy returns is legal across a full seeded game")
func policyPlaysALegalGame() throws {
  var generator = SeededGenerator(seed: 7)
  var engine = try GameEngine(playerNames: ["A", "B", "C"], shufflingWith: &generator)
  _ = try engine.send(.startRound)

  var safetyLimit = 5_000
  while safetyLimit > 0 {
    safetyLimit -= 1

    if case .gameComplete = engine.state.phase {
      break
    }
    if case .roundComplete = engine.state.phase {
      _ = try engine.send(.startNextRound)
      continue
    }

    let actingSeat: PlayerID? =
      switch engine.state.phase {
      case .awaitingTurn(let id): id
      case .awaitingAction(let decision): decision.sourcePlayerID
      default: nil
      }
    guard let actingSeat,
      let command = opponentCommand(for: engine.state, seat: actingSeat, using: &generator)
    else {
      Issue.record("the policy returned no command for phase \(engine.state.phase)")
      return
    }
    // Throws if the engine rejects the command, which fails the test.
    _ = try engine.send(command)
  }

  #expect(safetyLimit > 0, "the game did not terminate")
  guard case .gameComplete = engine.state.phase else {
    Issue.record("expected a completed game")
    return
  }
}
