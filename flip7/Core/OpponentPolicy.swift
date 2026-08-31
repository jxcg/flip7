/// Chooses a command for a computer-driven seat.
///
/// Returns `nil` when the seat has nothing to decide in the current phase. The
/// design spec specifies a non-optional return; that is unimplementable, since
/// no command is the honest answer for a phase the seat cannot act in.
///
/// The policy reads the draw pile only as a multiset. That is equivalent to the
/// card counting a human can already do, because deck composition is public and
/// every card is face up. Reading the pile's *order* would be cheating, and the
/// draw-order fairness test enforces that it does not.
public func opponentCommand<R: RandomNumberGenerator>(
  for state: GameState,
  seat: PlayerID,
  using generator: inout R
) -> GameCommand? {
  guard let player = state.players.first(where: { $0.id == seat }) else {
    return nil
  }

  switch state.phase {
  case .awaitingTurn(let playerID) where playerID == seat:
    return shouldHit(player, remaining: state.deck.drawPile) ? .hit(seat) : .stay(seat)
  case .awaitingAction(let decision) where decision.sourcePlayerID == seat:
    guard
      let target = actionTarget(
        for: decision,
        in: state,
        seat: seat,
        using: &generator
      )
    else {
      return nil
    }
    return .chooseActionTarget(cardID: decision.card.id, targetPlayerID: target)
  default:
    return nil
  }
}

/// Hits while the expected value of drawing beats the round score already held.
private func shouldHit(_ player: PlayerState, remaining: [GameCard]) -> Bool {
  // Staying is illegal without a card in front.
  guard player.hasCardInFront else {
    return true
  }

  let score = player.roundScore
  // Banking a winning total beats growing it. A bust would forfeit the game.
  if player.bankedScore + score.total >= Ruleset.targetScore {
    return false
  }
  guard !remaining.isEmpty else {
    return true
  }

  let held = Set(player.roundCards.numberValues)
  let safeCards = remaining.filter { card in
    guard case .number(let value) = card.kind else {
      // Only a duplicate number can bust. Modifiers and actions never do.
      return true
    }
    return !held.contains(value)
  }
  guard !safeCards.isEmpty else {
    return false
  }

  // A Second Chance absorbs a directly drawn duplicate, so this draw cannot
  // bust. It does not cover a drawn Flip Three whose forced draws overrun it.
  // ponytail: one-step model; add multi-draw lookahead only if play shows it matters.
  let bustProbability =
    player.secondChance != nil
    ? 0
    : Double(remaining.count - safeCards.count) / Double(remaining.count)

  let currentScore = Double(score.total)
  let expectedGain = averageGain(
    of: safeCards,
    held: held,
    numberSubtotal: score.numberSubtotal,
    multiplier: score.multiplier
  )
  let hitValue = (1 - bustProbability) * (currentScore + expectedGain)
  return hitValue > currentScore
}

/// Mean points a non-busting draw adds, averaged over every card that could
/// legally arrive rather than over number cards alone. Roughly fifteen of the
/// ninety-four cards score nothing directly, and ignoring them inflates the
/// expected gain enough to hit where staying is correct.
private func averageGain(
  of safeCards: [GameCard],
  held: Set<NumberValue>,
  numberSubtotal: Int,
  multiplier: Int
) -> Double {
  // Every safe number is one this seat does not hold, so at six uniques any of
  // them completes the bonus. Modifiers and actions never do.
  let completesFlipSeven = held.count == Ruleset.flipSevenNumberCount - 1

  let total = safeCards.reduce(0.0) { runningTotal, card in
    switch card.kind {
    case .number(let value):
      let faceValue = Double(value.rawValue * multiplier)
      let bonus = completesFlipSeven ? Double(Ruleset.flipSevenBonus) : 0
      return runningTotal + faceValue + bonus
    case .scoreModifier(.additive(let bonus)):
      return runningTotal + Double(bonus.rawValue)
    case .scoreModifier(.double):
      return runningTotal + Double(numberSubtotal * multiplier)
    case .action:
      // Actions score nothing directly. Their value is situational and is not
      // modelled here.
      return runningTotal
    }
  }
  return total / Double(safeCards.count)
}

/// Picks a target on merit across every legal target, with no special case for
/// the human seat. That is what spreads incoming actions across the table
/// instead of converging them on whoever happens to lead.
private func actionTarget<R: RandomNumberGenerator>(
  for decision: PendingActionDecision,
  in state: GameState,
  seat: PlayerID,
  using generator: inout R
) -> PlayerID? {
  let candidates = decision.legalTargetIDs.compactMap { id in
    state.players.first { $0.id == id }
  }
  guard !candidates.isEmpty else {
    return nil
  }

  switch decision.card.kind {
  case .action(.freeze):
    // Freeze sets the target to .frozen, which ScoreBreakdown scores normally,
    // so it banks their round score. The value is in denying future growth,
    // above all a Flip 7 run, never in punishing a current total.
    return bestHarm(among: candidates, avoiding: seat, using: &generator) { player in
      // Denial rises with how far along a hand is: more uniques means more
      // momentum and a shorter run to the bonus. Subtract half the score the
      // freeze banks for them, halved because freezing also removes the bust
      // risk they were carrying, which was going to cost them sometimes.
      let momentum = Double(player.roundCards.uniqueNumberCount * 5)
      return momentum - Double(player.roundScore.total) * 0.5
    }

  case .action(.flipThree):
    // Three forced draws bust whoever already holds the most unique numbers.
    // A held Second Chance absorbs one of those draws.
    return bestHarm(among: candidates, avoiding: seat, using: &generator) { player in
      let uniques = Double(player.roundCards.uniqueNumberCount)
      return player.secondChance == nil ? uniques : uniques - 1
    }

  case .action(.secondChance):
    // The engine auto-keeps a drawn Second Chance when the seat holds none, and
    // excludes every holder from legalTargetIDs, so the drawing seat is never
    // among its own targets. The card must be given away; it goes to whoever it
    // protects least. A self-targeting branch here would be unreachable.
    return bestHarm(among: candidates, avoiding: seat, using: &generator) { player in
      -Double(player.roundCards.uniqueNumberCount)
    }

  case .number, .scoreModifier:
    // The engine only pauses for action cards, so this is unreachable.
    return candidates.randomElement(using: &generator)?.id
  }
}

/// Returns the candidate that `harm` scores highest, excluding the acting seat
/// unless it is the only legal target.
///
/// Excluding self matters: `legalTargetIDs` for Freeze and Flip Three is every
/// active player, which always includes the seat holding the card. Ranking on a
/// harm metric without this makes a seat that has been drawing rank top on
/// itself and hand itself the punishment.
private func bestHarm<R: RandomNumberGenerator>(
  among candidates: [PlayerState],
  avoiding seat: PlayerID,
  using generator: inout R,
  harm: (PlayerState) -> Double
) -> PlayerID? {
  let others = candidates.filter { $0.id != seat }
  let pool = others.isEmpty ? candidates : others
  guard let best = pool.map(harm).max() else {
    return nil
  }
  let tied = pool.filter { harm($0) == best }
  return tied.randomElement(using: &generator)?.id
}
