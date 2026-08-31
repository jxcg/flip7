/// Chooses a command for a computer-driven seat.
///
/// Returns `nil` when the seat has nothing to decide in the current phase.
public func opponentCommand<R: RandomNumberGenerator>(
  for state: GameState,
  seat: PlayerID,
  using generator: inout R
) -> GameCommand? {
  nil
}
