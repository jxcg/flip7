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
