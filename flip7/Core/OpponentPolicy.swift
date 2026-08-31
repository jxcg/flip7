/// Chooses a command for a computer-driven seat.
///
/// Returns `nil` when the seat has nothing to decide in the current phase.
///
/// The policy reads the draw pile only as a multiset. That is equivalent to the
/// card counting a human can already do, because deck composition is public and
/// every card is face up. Reading the pile's *order* would be cheating, and
/// `fairnessIgnoresDrawOrder` enforces that it does not.
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
  // A Second Chance absorbs the next duplicate, so the next draw cannot bust.
  if player.secondChance != nil {
    return true
  }
  guard !remaining.isEmpty else {
    return true
  }

  let held = Set(player.roundCards.numberValues)
  let bustingCount = remaining.filter { card in
    if case .number(let value) = card.kind {
      return held.contains(value)
    }
    return false
  }.count
  guard bustingCount < remaining.count else {
    return false
  }

  let bustProbability = Double(bustingCount) / Double(remaining.count)
  let currentScore = Double(player.roundScore.total)
  let expectedGain = averageNumberValue(of: remaining, excluding: held)
  // One away from the bonus, the next unique number is worth far more than its
  // face value, and it ends the round.
  let flipSevenValue =
    held.count == Ruleset.flipSevenNumberCount - 1
    ? Double(Ruleset.flipSevenBonus)
    : 0

  let hitValue = (1 - bustProbability) * (currentScore + expectedGain + flipSevenValue)
  return hitValue > currentScore
}

private func averageNumberValue(
  of cards: [GameCard],
  excluding held: Set<NumberValue>
) -> Double {
  let values = cards.compactMap { card -> Int? in
    guard case .number(let value) = card.kind, !held.contains(value) else {
      return nil
    }
    return value.rawValue
  }
  guard !values.isEmpty else {
    return 0
  }
  return Double(values.reduce(0, +)) / Double(values.count)
}

private func uniqueNumberCount(_ player: PlayerState) -> Int {
  Set(player.roundCards.numberValues).count
}

/// Picks a target on merit across every legal target, with no special case for
/// any seat. That is what spreads incoming actions across the table instead of
/// converging them on whoever happens to lead.
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
    let mostAdvanced = candidates.map(uniqueNumberCount).max() ?? 0
    let chasers = candidates.filter { uniqueNumberCount($0) == mostAdvanced }
    // Among equally advanced chases, freeze whoever we gift the least.
    let smallestGift = chasers.map(\.roundScore.total).min() ?? 0
    let tied = chasers.filter { $0.roundScore.total == smallestGift }
    return tied.randomElement(using: &generator)?.id

  case .action(.flipThree):
    // Three forced draws bust whoever already holds the most unique numbers.
    // A held Second Chance absorbs one of those draws.
    return bestTarget(among: candidates, using: &generator) { player in
      player.secondChance == nil
        ? uniqueNumberCount(player)
        : uniqueNumberCount(player) - 1
    }

  case .action(.secondChance):
    // Keeping it is always best. When self-targeting is illegal the card must
    // still go somewhere, so give it to the seat it protects least.
    if candidates.contains(where: { $0.id == seat }) {
      return seat
    }
    return bestTarget(among: candidates, using: &generator) { player in
      -uniqueNumberCount(player)
    }

  case .number, .scoreModifier:
    return candidates.randomElement(using: &generator)?.id
  }
}

/// Returns the highest-ranked candidate, breaking ties with the generator so
/// equally good targets are not always the same player. `rank` returns `Int`
/// rather than a tuple because Swift tuples do not conform to `Comparable`.
private func bestTarget<R: RandomNumberGenerator>(
  among candidates: [PlayerState],
  using generator: inout R,
  rank: (PlayerState) -> Int
) -> PlayerID? {
  guard let best = candidates.map(rank).max() else {
    return nil
  }
  let tied = candidates.filter { rank($0) == best }
  return tied.randomElement(using: &generator)?.id
}
