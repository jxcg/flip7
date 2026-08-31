# Computer opponents and solo play

**Status:** approved design, not yet implemented. Supersedes the pass-and-play
decisions recorded in issue #19 and the handoff work shipped in issue #5.

## Context

Issue #19 recorded both "local pass-and-play is required" and "solo play with
computer opponents is required". The owner has since decided that solo play is
the only mode the UI offers for the first release: one human seat and 2-8
computer opponents, with no device passing.

`GameEngine` keeps its 3-9 seat support unchanged. A seat is an id, a name and
cards, with no notion of who drives it, so the engine already accommodates the
nearby-device mode under evaluation in issue #24 without modification. Removing
pass-and-play is a presentation decision, not a rules decision.

### Owner decisions taken during design

| Decision | Choice |
|---|---|
| Play modes in the UI | Solo only. One human, 2-8 computer opponents. |
| Engine seat support | Unchanged, so LAN play stays possible. |
| Difficulty levels | One well-tuned level. No difficulty picker. |
| Computer turn pacing | Paced, one card at a time. |
| Pacing interval | Random 2-4 seconds per computer decision. |
| Action targeting | Best play, evaluated across all legal targets so opponents also target each other. |
| Setup screen | Your name plus an opponent-count stepper. Generated opponent names. |
| Outcome dismissal | No Continue button anywhere. Results display without blocking. |
| Design language doc | Tracked in the repository, still marked non-binding. |

## Non-goals

- No difficulty tiers, no opponent personalities, no adaptive difficulty.
- No visual design. Issue #6 remains blocked and unapproved.
- No changes to `GameEngine`, `Deck`, `Scoring` or `Ruleset`.
- No persistence of in-progress solo games. That stays in issue #9.
- No networking. Issue #24 is unaffected by this work.

## Architecture

Three units, each independently testable.

### Seat ownership (`GameSession`)

One new property, `humanPlayerID: PlayerID`. Every other seat is computer
driven. This is deliberately a single property rather than a seat-to-controller
map: a map is speculative until issue #24 produces evidence that nearby play
ships, and replacing one property with a map later is a small change.

### The policy (`Flip7Core/OpponentPolicy.swift`)

A pure function:

```swift
public func opponentCommand<R: RandomNumberGenerator>(
  for state: GameState,
  seat: PlayerID,
  using generator: inout R
) -> GameCommand
```

It lives in `Flip7Core` rather than a new target because it is
platform-independent, value-typed and needs no UI, async or MainActor context to
test. A separate `Flip7Opponent` target is the cleaner layering but costs two
package targets and an Xcode project change to make a philosophical point about
one file. Promote it to its own target if the policy outgrows a single file.

A policy is not a rule, and it must not become one. It only ever returns a
`GameCommand` that `GameEngine` is free to reject.

### The turn driver (`GameSession`)

When the acting seat is not `humanPlayerID`, a `Task` sleeps for an interval
sampled from `turnDelayRange` (default 2-4 seconds) and then sends the policy's
command.

The decision and the delay are separated:

```swift
func opponentCommandIfNeeded() -> GameCommand?   // synchronous, no timing
```

returns the command for the acting seat when that seat is computer driven, and
`nil` otherwise. The async wrapper does nothing but sleep and send it. This is
not a testing seam; the decision logic has no reason to sit in an async context,
and moving it out leaves an async remainder of two lines with nothing in it
worth testing. Tests drive a whole solo game by calling the synchronous method
in a loop, so no test touches `Task` or timing.

Concurrency safety reuses the existing `inputVersion` mechanism rather than
introducing a second one. The task captures `inputVersion` before sleeping;
`send` already drops any command whose version is stale, so a resolved round, a
reset game or a raced human tap all invalidate an in-flight opponent turn for
free. Chained opponent turns need no loop, because `send` re-schedules on every
state change. The task is cancelled in `resetGame()`.

## Strategy

All information in Flip 7 is public. Every card is face up and deck composition
is fixed and printed on the box, so there is no hidden state for difficulty to
withhold. Difficulty can only come from the quality of the policy.

### Hit or stay

Let `front` be the number values already in front of the seat, and `remaining`
be the multiset of cards still in the draw pile.

- `P(bust)` is the share of `remaining` whose value is already in `front`.
- Holding Second Chance makes the next duplicate survivable, so `P(bust)` for
  the next draw is zero.
- Staying banks the current round score. Busting forfeits it.
- Hit while the expected value of drawing exceeds the round score already held.
- At six unique numbers, the Flip 7 bonus and round-ending effect raise the
  value of one more unique sharply. The policy should push at six.
- A round score that would win the game outright is worth banking rather than
  growing.

### Targeting

Freeze sets the target to `.frozen`, which is distinct from `.busted`.
`ScoreBreakdown` discriminates only on `isBusted`, so **a frozen player keeps
and banks their round score**. Freezing the round leader hands them their
points. The value of a Freeze is denying future growth, not punishing a current
total.

- **Freeze** maximises denied future gain minus the score it locks in. The
  strongest target is an active player close to seven unique numbers.
- **Flip Three** picks the legal target most likely to bust across three forced
  draws, which correlates with how many numbers they already hold.
- **Second Chance** is kept when self-targeting is legal. When it is not, it
  goes to the active player it helps least, meaning the fewest cards in front.

Targets are evaluated on merit across every legal target with no special case
for the human seat, which is what spreads incoming actions across the table
rather than converging them on whoever leads. Ties are broken with the injected
generator.

## Fairness

Reading the draw pile as a **multiset** is equivalent to the card counting a
sharp human can already do from public information. Reading its **order** is
cheating.

This makes fairness a single structural test: two states with an identical
remaining multiset but a deliberately different top card, one a duplicate that
would bust the seat and one safe, must yield the same command. The pair is
constructed rather than shuffled. A seeded shuffle would be deterministic but
only accidentally strong, because a shuffle that happened to preserve the top
card gives a permanently green test that proves nothing and never says so. It
permits the cheap implementation and fails the dishonest one. Passing a
restricted view of the table to the policy would make cheating impossible rather
than merely detected, at the cost of a new type and its plumbing; the test buys
the same guarantee for about ten lines and is the right rung to stop at.

## Presentation changes

### Removed

`revealedPlayerID`, `needsHandoff`, `isPresentedPlayerRevealed`,
`revealForCurrentPlayer()`, `conceal()`, `announceHandoff()`, the handoff
`Section` in `GameTableView`, the `scenePhase` concealment wiring in
`ContentView`, the navigation-title ternary, `continueAfterOutcome()` and the
Continue button.

Removing the Continue button also removes the `turnOutcome == nil` guard in
`send`. This is safe: `inputVersion` is what actually rejects duplicate input,
and it is the guard the stale-input test at `cf98935` exercises. The outcome
guard was belt-and-braces for the handoff flow that is going away.

### Changed

- `turnOutcome` stops gating and becomes a display-only latest-activity line for
  every actor. VoiceOver announcements are unaffected; they already fire from
  `send`.
- Setup replaces the editable player list with one name field and a 2-8 opponent
  stepper.
- Opponent names are generated **after** reading the human's name, skipping any
  candidate that normalizes to it. `GameEngine` trims and lowercases names and
  throws `duplicatePlayerName` on a collision, so generating first would fail on
  the default path: today's setup pre-fills `Player 1`...`Player N`, and a human
  who presses Start without typing would be told "Player 1 is used more than
  once" about a name they never entered. `GameSession.addPlayer` already uses
  this normalize-and-skip approach.

## Testing

| Property | Test |
|---|---|
| Policy is deterministic | Same state and seeded generator yields the same command. |
| Policy is fair | A busting top card and a safe top card over the same remaining multiset yield the same command. |
| Policy is legal | Every returned command is accepted by `GameEngine` across a seeded full game. |
| Freeze is not self-defeating | Given a high-scoring and a low-scoring active target, the policy does not freeze the high scorer purely on score. |
| Targeting spreads | With two equally good targets, the choice varies with the generator; a strictly better opponent target is preferred over the human. |
| Solo game completes | A seeded solo game driven synchronously through `opponentCommandIfNeeded()` reaches a final result. |
| Pacing is testable | `turnDelayRange` set to zero keeps the suite fast; the default never appears in tests. |

Delay randomness is never reproduced in tests, only switched off, so no seeded
generator needs threading through the driver.

## Documentation amendments

- **Issue #19**: record solo-only play, superseding "local pass-and-play is
  required". Record the one-difficulty-level decision and its rationale.
- **`docs/PRODUCT.md`**: amend the foundation line and complete-release gate
  item 3, which currently requires "private handoff in local play".
- **`docs/DESIGN_LANGUAGE.md`**: track it in the repository, still marked
  non-binding. Amend §7's turn-handoff paragraph and §9's `turn handoff`
  feedback row, both of which describe a deleted screen. Amend §11's
  justification, which rests on "pass-and-play is mostly a human thinking", and
  its verification gate 2, "FPS gauge on an untouched table → 0 frames", which
  a paced computer turn will now fail. The gate should read "a table awaiting
  human input".
- **`docs/palette_check.py`**: track it so CI can run it.

## Open questions

- **§7 opponent rendering.** §7 compresses opponents to hue dots because
  pass-and-play meant nobody watched an opponent's turn. In solo play every
  opponent turn is watched, so a 2-4 second wait would show a single dot
  appearing. This does not bite yet, because `PlayerTableRow` currently renders
  opponent cards in full. It becomes a real conflict when §7's compression
  lands, and belongs to issue #6.
- **Dead time when the human is out of the round.** Busting early means
  watching the rest of the round with nothing at stake, up to 60-90 seconds at
  eight opponents. Fast-forwarding once the human has no further decision was
  considered and rejected for now: it only describes busting, since a player who
  stayed has a score to defend and every opponent draw is tension rather than
  tedium, and it costs a second pacing behaviour in the driver to solve a
  problem nobody has felt yet. Revisit after first play.
- **Pacing at high opponent counts.** At an average 3 seconds per decision and
  3-5 draws per player per round, two opponents cost roughly 25 seconds of
  watching per round and eight cost roughly 90, making a full game 8-13 minutes
  of waiting. Shipping flat 2-4 seconds is the owner's decision. If it bites,
  scaling the interval down as opponent count rises is a one-line change.
- **Symbol drift.** §6 specifies `arrow.trianglehead.2.clockwise` and
  `shield.lefthalf.filled`; `GamePresentation.swift:40,42` use
  `arrow.triangle.2.circlepath` and `shield`. Resolve in issue #6.

## Issue decomposition

Issue #19 requires that approving computer opponents creates focused issues for
strategy, difficulty, fairness, deterministic testing and performance. Three
issues cover all five.

**A. [Product] Record solo play and retire pass-and-play.** Documentation only.
The amendments above, plus tracking the design doc and palette checker.
Covers: difficulty (recorded as one level).

**B. [Core] Add the opponent decision policy.** The pure policy, its strategy,
and its tests. Depends on A.
Covers: strategy, fairness, deterministic testing.

**C. [UI] Solo setup, computer turn pacing, and handoff removal.** The setup
screen, the turn driver, and the deletions. Depends on B and on #7 merging.
Covers: performance.
