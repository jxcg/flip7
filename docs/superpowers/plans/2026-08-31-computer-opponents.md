# Computer Opponents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flip 7 a solo game against computer opponents, with no device passing.

**Architecture:** One pure decision function in `Flip7Core` maps a `GameState` and a seat to a `GameCommand`. `GameSession` owns a single `humanPlayerID`; every other seat is driven by that function through a synchronous `opponentCommandIfNeeded()`, wrapped by a thin async task that only sleeps and sends. `GameEngine` is not modified, so its 3 to 9 seat support survives for the nearby-device study in #24.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, SPM (`Flip7Core`, `Flip7Session`), iOS 18 deployment target.

**Spec:** `docs/superpowers/specs/2026-08-31-computer-opponents-design.md`

**Note on the sample code:** the snippets below are a drafting aid, not verified
source. Compile every one before trusting it.

## Global Constraints

- Conventional Commits on every commit (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).
- One GitHub issue at a time. Branch `issue-X` cut from the latest `main`.
- Full suite: `swift test -Xswiftc -warnings-as-errors`. All 40 existing tests must stay green.
- Signing-free build: `xcodebuild -project flip7.xcodeproj -scheme flip7 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/flip7-derived-data CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- Red-green TDD evidence per behavior change: commit the failing test first, record that it failed for the expected reason, then fix in a separate commit.
- No changes to `GameEngine.swift`, `Deck.swift`, `Scoring.swift`, or `Ruleset.swift`.
- No visual design. Issue #6 is unapproved and out of scope.
- Rules stay in the core. A policy returns a `GameCommand` the engine is free to reject; it never decides legality itself.

## Prerequisites

1. **PR #38 is merged** as `c1c5762`, so `main` already contains `GameEvent.actionDiscardedWithoutTarget`, the `Flip7Session` target, and `GameTableView`. Branch both phases from current `main`.
2. **Issue #39 is executed from its own checklist**, not from this plan. It is documentation only and has no test cycle. Its branch `issue-39` already carries commit `0a940e6` with the spec and the newly tracked design language.

## Deviation from the spec

The spec gives the policy signature as returning `GameCommand`. This plan returns `GameCommand?`. A non-optional return has no honest value for a phase the seat cannot act in, and the alternatives are a crash or a silently wrong `.stay`. `nil` means "this seat has nothing to decide right now". Update the spec's signature when phase 1 lands.

---

# Phase 1 — Issue #40: the opponent decision policy

Branch: `issue-40`, cut from `main` after #38 merges.

### Task 1: Hit or stay

**Files:**
- Create: `flip7/Core/OpponentPolicy.swift`
- Test: `Tests/Flip7CoreTests/OpponentPolicyTests.swift`

**Interfaces:**
- Consumes: `GameState`, `PlayerState`, `GameCommand`, `RoundCards.numberValues`, `Ruleset.flipSevenNumberCount`, `Ruleset.flipSevenBonus`.
- Produces: `public func opponentCommand<R: RandomNumberGenerator>(for state: GameState, seat: PlayerID, using generator: inout R) -> GameCommand?`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import Flip7Core

private func seat(_ n: Int) -> PlayerID { PlayerID(rawValue: n) }

/// Builds a state where `seat(0)` is on turn holding `held`, and the draw pile
/// contains exactly `pile`.
private func turnState(held: [NumberValue], pile: [NumberValue]) throws -> GameState {
  let engine = try GameEngine(
    playerNames: ["A", "B", "C"],
    deck: Deck(drawPile: pile.enumerated().map {
      GameCard(id: CardID(rawValue: 900 + $0.offset), kind: .number($0.element))
    })
  )
  var state = engine.state
  state.players[0].roundCards = RoundCards(cards: held.enumerated().map {
    GameCard(id: CardID(rawValue: 800 + $0.offset), kind: .number($0.element))
  })
  state.phase = .awaitingTurn(seat(0))
  return state
}

@Test("An empty hand always hits")
func emptyHandHits() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try turnState(held: [], pile: [.five, .six, .seven])
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .hit(seat(0)))
}

@Test("A hand stays when every remaining card would bust it")
func certainBustStays() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try turnState(held: [.five, .six], pile: [.five, .six, .five])
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .stay(seat(0)))
}

@Test("Holding Second Chance makes the next draw free, so it hits")
func secondChanceHits() throws {
  var generator = SystemRandomNumberGenerator()
  var state = try turnState(held: [.five, .six], pile: [.five, .six, .five])
  state.players[0].secondChance = GameCard(id: CardID(rawValue: 700), kind: .action(.secondChance))
  #expect(opponentCommand(for: state, seat: seat(0), using: &generator) == .hit(seat(0)))
}

@Test("A seat with no decision to make returns nil")
func noDecisionReturnsNil() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try turnState(held: [], pile: [.five])
  #expect(opponentCommand(for: state, seat: seat(1), using: &generator) == nil)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7CoreTests.emptyHandHits'`
Expected: FAIL to build with "cannot find 'opponentCommand' in scope".

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/Flip7CoreTests/OpponentPolicyTests.swift
git commit -m "test: cover opponent hit and stay decisions"
```

- [ ] **Step 4: Write the minimal implementation**

```swift
/// Chooses a command for a computer-driven seat.
///
/// Returns `nil` when the seat has nothing to decide in the current phase.
/// The policy reads the draw pile only as a multiset. Reading its order would
/// be cheating, and `fairnessIgnoresDrawOrder` enforces that.
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
    return shouldHit(player, remaining: state.deck.drawPile)
      ? .hit(seat)
      : .stay(seat)
  default:
    return nil
  }
}

/// Hits while the expected value of drawing beats the round score already held.
private func shouldHit(_ player: PlayerState, remaining: [GameCard]) -> Bool {
  guard player.hasCardInFront else {
    return true
  }
  // Staying is illegal without a card in front, and a Second Chance absorbs
  // the next duplicate, so the next draw cannot bust this seat.
  if player.secondChance != nil {
    return true
  }
  guard !remaining.isEmpty else {
    return true
  }

  let held = Set(player.roundCards.numberValues)
  let bustingCards = remaining.filter { card in
    if case .number(let value) = card.kind {
      return held.contains(value)
    }
    return false
  }

  let bustProbability = Double(bustingCards.count) / Double(remaining.count)
  let safeCards = remaining.count - bustingCards.count
  guard safeCards > 0 else {
    return false
  }

  let currentScore = Double(player.roundScore.total)
  let expectedGain = averageNumberValue(of: remaining, excluding: held)
  // One away from the bonus, the next unique number is worth far more than
  // its face value and ends the round.
  let flipSevenValue =
    held.count == Ruleset.flipSevenNumberCount - 1
    ? Double(Ruleset.flipSevenBonus)
    : 0

  let stayValue = currentScore
  let hitValue = (1 - bustProbability) * (currentScore + expectedGain + flipSevenValue)
  return hitValue > stayValue
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS, 44 tests.

- [ ] **Step 6: Commit**

```bash
git add flip7/Core/OpponentPolicy.swift
git commit -m "feat: add opponent hit and stay policy"
```

---

### Task 2: Freeze targeting

**Files:**
- Modify: `flip7/Core/OpponentPolicy.swift`
- Test: `Tests/Flip7CoreTests/OpponentPolicyTests.swift`

**Interfaces:**
- Consumes: `PendingActionDecision.sourcePlayerID`, `.card`, `.legalTargetIDs`.
- Produces: `.chooseActionTarget(cardID:targetPlayerID:)` for `.action(.freeze)`.

- [ ] **Step 1: Write the failing tests**

```swift
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

@Test("Freeze denies a Flip 7 chase rather than punishing the leader")
func freezeTargetsTheFlipSevenChase() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try actionState(card: .freeze, targets: [seat(1), seat(2)]) { state in
    // Seat 1 holds a big score in few cards. Freezing banks it for them.
    state.players[1].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 500), kind: .number(.twelve)),
      GameCard(id: CardID(rawValue: 501), kind: .number(.eleven)),
    ])
    // Seat 2 is five uniques into a Flip 7 run.
    state.players[2].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 510), kind: .number(.one)),
      GameCard(id: CardID(rawValue: 511), kind: .number(.two)),
      GameCard(id: CardID(rawValue: 512), kind: .number(.three)),
      GameCard(id: CardID(rawValue: 513), kind: .number(.four)),
      GameCard(id: CardID(rawValue: 514), kind: .number(.five)),
    ])
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(2))
  )
}

@Test("Freeze never picks an illegal target")
func freezeStaysLegal() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try actionState(card: .freeze, targets: [seat(2)])
  guard case .chooseActionTarget(_, let target)? =
    opponentCommand(for: state, seat: seat(0), using: &generator)
  else {
    Issue.record("expected a target choice")
    return
  }
  #expect(target == seat(2))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7CoreTests.freezeTargetsTheFlipSevenChase'`
Expected: FAIL, because the policy returns `nil` for `.awaitingAction`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/Flip7CoreTests/OpponentPolicyTests.swift
git commit -m "test: cover opponent freeze targeting"
```

- [ ] **Step 4: Write the implementation**

Add to the `switch` in `opponentCommand`, before `default`:

```swift
  case .awaitingAction(let decision) where decision.sourcePlayerID == seat:
    guard let target = actionTarget(
      for: decision,
      in: state,
      seat: seat,
      using: &generator
    ) else {
      return nil
    }
    return .chooseActionTarget(cardID: decision.card.id, targetPlayerID: target)
```

And add:

```swift
/// Picks a target on merit across every legal target, with no special case for
/// any seat. That is what spreads incoming actions across the table instead of
/// converging them on whoever leads.
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
    // Freeze sets the target to .frozen, which scores normally, so it banks
    // their round score. The value is in denying future growth, especially a
    // Flip 7 run, not in punishing a current total.
    let uniqueCount = { (player: PlayerState) in
      Set(player.roundCards.numberValues).count
    }
    let mostAdvanced = candidates.map(uniqueCount).max() ?? 0
    let chasers = candidates.filter { uniqueCount($0) == mostAdvanced }
    // Among equally advanced chases, freeze the one whose score we gift least.
    let smallestGift = chasers.map(\.roundScore.total).min() ?? 0
    let tied = chasers.filter { $0.roundScore.total == smallestGift }
    return tied.randomElement(using: &generator)?.id
  default:
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add flip7/Core/OpponentPolicy.swift
git commit -m "feat: target freeze at the strongest Flip 7 chase"
```

---

### Task 3: Flip Three and Second Chance targeting

**Files:**
- Modify: `flip7/Core/OpponentPolicy.swift`
- Test: `Tests/Flip7CoreTests/OpponentPolicyTests.swift`

**Interfaces:**
- Consumes: the `actionTarget` switch from Task 2.
- Produces: no new public API.

- [ ] **Step 1: Write the failing tests**

```swift
@Test("Flip Three targets the seat most likely to bust")
func flipThreeTargetsTheFullestHand() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try actionState(card: .flipThree, targets: [seat(1), seat(2)]) { state in
    state.players[1].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 520), kind: .number(.one))
    ])
    state.players[2].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 530), kind: .number(.one)),
      GameCard(id: CardID(rawValue: 531), kind: .number(.two)),
      GameCard(id: CardID(rawValue: 532), kind: .number(.three)),
      GameCard(id: CardID(rawValue: 533), kind: .number(.four)),
    ])
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(2))
  )
}

@Test("Second Chance is kept when the seat may target itself")
func secondChanceIsKept() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try actionState(card: .secondChance, targets: [seat(0), seat(1)])
  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(0))
  )
}

@Test("A Second Chance that cannot be kept goes to whoever it helps least")
func secondChanceGoesToTheSafestOpponent() throws {
  var generator = SystemRandomNumberGenerator()
  let state = try actionState(card: .secondChance, targets: [seat(1), seat(2)]) { state in
    state.players[1].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 540), kind: .number(.one))
    ])
    state.players[2].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 550), kind: .number(.one)),
      GameCard(id: CardID(rawValue: 551), kind: .number(.two)),
      GameCard(id: CardID(rawValue: 552), kind: .number(.three)),
    ])
  }

  #expect(
    opponentCommand(for: state, seat: seat(0), using: &generator)
      == .chooseActionTarget(cardID: CardID(rawValue: 600), targetPlayerID: seat(1))
  )
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7CoreTests.secondChanceIsKept'`
Expected: FAIL, because the `default` branch picks a random legal target.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/Flip7CoreTests/OpponentPolicyTests.swift
git commit -m "test: cover opponent Flip Three and Second Chance targeting"
```

- [ ] **Step 4: Write the implementation**

Replace the `default` branch of the `actionTarget` switch:

```swift
  case .action(.flipThree):
    // Three forced draws bust whoever already holds the most unique numbers.
    // A held Second Chance absorbs one of those draws.
    return bestTarget(among: candidates, using: &generator) { player in
      let uniques = Set(player.roundCards.numberValues).count
      return player.secondChance == nil ? uniques : uniques - 1
    }
  case .action(.secondChance):
    // Keeping it is always best. When self-targeting is illegal the card must
    // still go somewhere, so give it to the seat it protects least.
    if candidates.contains(where: { $0.id == seat }) {
      return seat
    }
    return bestTarget(among: candidates, using: &generator) { player in
      -Set(player.roundCards.numberValues).count
    }
  case .number, .scoreModifier:
    return candidates.randomElement(using: &generator)?.id
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add flip7/Core/OpponentPolicy.swift
git commit -m "feat: target Flip Three and Second Chance on merit"
```

---

### Task 4: Fairness, determinism, and full-game legality

**Files:**
- Test: `Tests/Flip7CoreTests/OpponentPolicyTests.swift`

**Interfaces:**
- Consumes: everything above. No production code should change; if a test here fails, that is a real defect.

- [ ] **Step 1: Write the failing tests**

```swift
@Test("The policy ignores draw order, so it cannot peek at the next card")
func fairnessIgnoresDrawOrder() throws {
  // Same remaining multiset, deliberately different top card: one would bust
  // the seat, one is safe. Constructed rather than shuffled, because a shuffle
  // that happened to preserve the top card would pass while proving nothing.
  let busting = GameCard(id: CardID(rawValue: 300), kind: .number(.five))
  let safe = GameCard(id: CardID(rawValue: 301), kind: .number(.nine))
  let filler = (0..<20).map {
    GameCard(id: CardID(rawValue: 400 + $0), kind: .number(.nine))
  }

  func command(topCard first: GameCard, then second: GameCard) throws -> GameCommand? {
    let engine = try GameEngine(
      playerNames: ["A", "B", "C"],
      deck: Deck(drawPile: [first, second] + filler)
    )
    var state = engine.state
    state.players[0].roundCards = RoundCards(cards: [
      GameCard(id: CardID(rawValue: 200), kind: .number(.five))
    ])
    state.phase = .awaitingTurn(seat(0))
    var generator = SystemRandomNumberGenerator()
    return opponentCommand(for: state, seat: seat(0), using: &generator)
  }

  #expect(try command(topCard: busting, then: safe) == command(topCard: safe, then: busting))
}

@Test("The policy is deterministic for a given state and seed")
func policyIsDeterministic() throws {
  let state = try turnState(held: [.five], pile: [.five, .nine, .three])
  var a = SeededGenerator(seed: 42)
  var b = SeededGenerator(seed: 42)
  #expect(
    opponentCommand(for: state, seat: seat(0), using: &a)
      == opponentCommand(for: state, seat: seat(0), using: &b)
  )
}

@Test("Every command the policy returns is legal across a full seeded game")
func policyPlaysALegalGame() throws {
  var generator = SeededGenerator(seed: 7)
  var engine = try GameEngine(
    playerNames: ["A", "B", "C"],
    shufflingWith: &generator
  )
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
```

If `SeededGenerator` does not already exist in the test target, add it:

```swift
/// A small reproducible generator. Tests must not depend on system randomness.
struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed &+ 0x9E37_79B9_7F4A_7C15
  }

  mutating func next() -> UInt64 {
    state = state &+ 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7CoreTests.fairnessIgnoresDrawOrder'`
Expected: PASS if the implementation is honest. A FAIL here means the policy reads draw order and must be fixed, not the test.

- [ ] **Step 3: Run the full suite and the build**

Run both Global Constraints commands. Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add Tests/Flip7CoreTests/OpponentPolicyTests.swift
git commit -m "test: prove the opponent policy is fair, deterministic, and legal"
```

- [ ] **Step 5: Open the PR for #40**

Record in the PR body: the review range, findings or `None`, both green checks, the red-green evidence per task, and the spec deviation on the optional return.

---

# Phase 2 — Issue #41: solo setup, pacing, and handoff removal

Branch: `issue-41`, cut from `main` after #40 merges.

### Task 5: Seat ownership and the synchronous decision step

**Files:**
- Modify: `flip7/GameSession.swift`
- Test: `Tests/Flip7SessionTests/GameSessionTests.swift`

**Interfaces:**
- Consumes: `opponentCommand(for:seat:using:)` from Task 1.
- Produces: `var humanPlayerID: PlayerID`, `func opponentCommandIfNeeded() -> GameCommand?`, `func playOpponentTurnIfNeeded() -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
@Test("A solo game plays to a final result with no human input")
func soloGameCompletes() throws {
  let session = GameSession()
  session.humanName = "Josh"
  session.opponentCount = 3
  #expect(session.start(with: .canonical))

  var safetyLimit = 5_000
  while safetyLimit > 0 {
    safetyLimit -= 1
    if case .gameComplete = session.state?.phase {
      break
    }
    if session.playOpponentTurnIfNeeded() { continue }
    // The human seat plays a fixed, boring strategy so the test stays about
    // the driver rather than about human choices.
    guard let seat = session.actingPlayerID, seat == session.humanPlayerID else {
      break
    }
    session.stay(seat, inputVersion: session.inputVersion)
  }

  #expect(safetyLimit > 0)
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7SessionTests.soloGameCompletes'`
Expected: FAIL to build, `humanName`, `opponentCount` and `playOpponentTurnIfNeeded` do not exist.

- [ ] **Step 3: Commit the failing test**

```bash
git add Tests/Flip7SessionTests/GameSessionTests.swift
git commit -m "test: cover a solo game driven without timing"
```

- [ ] **Step 4: Implement**

```swift
  var humanName = "Player 1"
  var opponentCount = 2
  private(set) var humanPlayerID = PlayerID(rawValue: 0)

  /// The command for the acting seat when that seat is computer driven.
  /// Synchronous and free of timing, so tests drive a whole game in a loop
  /// without touching `Task`.
  func opponentCommandIfNeeded() -> GameCommand? {
    guard let state, let seat = actingPlayerID, seat != humanPlayerID else {
      return nil
    }
    var generator = SystemRandomNumberGenerator()
    return opponentCommand(for: state, seat: seat, using: &generator)
  }

  /// Plays one computer decision. Returns false when the acting seat is the
  /// human or the game has nothing to do.
  @discardableResult
  func playOpponentTurnIfNeeded() -> Bool {
    guard let command = opponentCommandIfNeeded() else {
      return false
    }
    send(command, outcomeOwnerID: actingPlayerID, inputVersion: inputVersion)
    return true
  }
```

Replace `playerDrafts` construction in `start()` with names built from `humanName` and `opponentCount`. Generate opponent names *after* reading the human name, skipping anything that normalizes to it:

```swift
  /// `GameEngine` trims and lowercases names and rejects duplicates, so an
  /// opponent must never be handed the name the human typed.
  private func playerNames() -> [String] {
    let human = humanName.trimmingCharacters(in: .whitespacesAndNewlines)
    var names = [human]
    var number = 1
    while names.count < opponentCount + 1 {
      let candidate = "Opponent \(number)"
      number += 1
      guard candidate.lowercased() != human.lowercased() else {
        continue
      }
      names.append(candidate)
    }
    return names
  }
```

- [ ] **Step 5: Run the tests**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add flip7/GameSession.swift
git commit -m "feat: drive computer seats from the opponent policy"
```

---

### Task 6: The paced async wrapper

**Files:**
- Modify: `flip7/GameSession.swift`
- Test: `Tests/Flip7SessionTests/GameSessionTests.swift`

**Interfaces:**
- Consumes: `playOpponentTurnIfNeeded()` from Task 5.
- Produces: `var turnDelayRange: ClosedRange<Duration>`, `private var opponentTask: Task<Void, Never>?`.

- [ ] **Step 1: Write the failing test**

```swift
@Test("Resetting the game cancels an in-flight opponent turn")
func resetCancelsOpponentTurn() throws {
  let session = GameSession()
  session.turnDelayRange = .zero ... .zero
  session.opponentCount = 2
  #expect(session.start(with: .canonical))
  session.resetGame()
  #expect(session.state == nil)
  #expect(session.opponentCommandIfNeeded() == nil)
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7SessionTests.resetCancelsOpponentTurn'`
Expected: FAIL to build, `turnDelayRange` does not exist.

- [ ] **Step 3: Commit the failing test**

```bash
git add Tests/Flip7SessionTests/GameSessionTests.swift
git commit -m "test: cover opponent turn cancellation on reset"
```

- [ ] **Step 4: Implement**

```swift
  /// Sampled per computer decision. Tests set both bounds to zero; the
  /// randomness never needs reproducing, only switching off.
  var turnDelayRange: ClosedRange<Duration> = .seconds(2) ... .seconds(4)
  private var opponentTask: Task<Void, Never>?

  private func scheduleOpponentTurn() {
    guard opponentCommandIfNeeded() != nil else {
      return
    }
    let version = inputVersion
    opponentTask?.cancel()
    opponentTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let low = self.turnDelayRange.lowerBound
      let high = self.turnDelayRange.upperBound
      // Duration supports * by Double, so no seconds accessor is needed.
      let delay = low + (high - low) * Double.random(in: 0...1)
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled, self.inputVersion == version else {
        return
      }
      self.playOpponentTurnIfNeeded()
    }
  }
```

Call `scheduleOpponentTurn()` at the end of the successful branch of `send` and at the end of `start`. Add `opponentTask?.cancel()` and `opponentTask = nil` to `resetGame()`.

- [ ] **Step 5: Run the tests**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS. No test should take measurably longer than before.

- [ ] **Step 6: Commit**

```bash
git add flip7/GameSession.swift
git commit -m "feat: pace computer turns between two and four seconds"
```

---

### Task 7: Remove handoff and the Continue button

**Files:**
- Modify: `flip7/GameSession.swift`, `flip7/GameTableView.swift`, `flip7/ContentView.swift`
- Test: `Tests/Flip7SessionTests/GameSessionTests.swift`

**Interfaces:**
- Produces: no new API. This task is a deletion.

- [ ] **Step 1: Delete**

From `GameSession.swift`: `revealedPlayerID`, `needsHandoff`, `isPresentedPlayerRevealed`, `revealForCurrentPlayer()`, `conceal()`, `announceHandoff()`, `continueAfterOutcome()`, the `revealedPlayerID` checks in `hit`, `stay` and `chooseActionTarget`, and the `turnOutcome == nil` clause in `send`'s guard.

`inputVersion` is what rejects duplicate input, and it is the guard `cf98935` exercises, so removing the outcome clause is safe.

From `GameTableView.swift`: the `handoff(_:)` section, its call site, the `.disabled(session.needsHandoff)` modifier, and the Continue button in `outcomeSection`. Rename the section header from `"Latest Result"` to `"Latest Activity"`, since it no longer gates anything.

From `ContentView.swift`: the `scenePhase` environment value and its `onChange`, and the `navigationTitle` ternary, which becomes `.navigationTitle("Game")`.

- [ ] **Step 2: Update the existing session test**

`GameSessionTests.swift:33` branches on `session.needsHandoff`. Remove that branch and the `session.continueAfterOutcome()` calls the seeded test makes.

- [ ] **Step 3: Run the full suite**

Run: `swift test -Xswiftc -warnings-as-errors`
Expected: PASS. Any failure here is a real coupling to the handoff flow that must be understood before being deleted.

- [ ] **Step 4: Commit**

```bash
git commit -am "refactor: remove pass-and-play handoff and the Continue gate"
```

---

### Task 8: The solo setup screen

**Files:**
- Modify: `flip7/ContentView.swift`

**Interfaces:**
- Consumes: `humanName`, `opponentCount` from Task 5.

- [ ] **Step 1: Replace the player list**

In `NewGameView`, replace the `ForEach` over `playerDrafts`, the `EditButton`, the Add Player button, and the delete and move handlers with:

```swift
      Section {
        TextField("Your name", text: $session.humanName)
          .textContentType(.name)
          .accessibilityLabel("Your name")

        Stepper(
          "Opponents: \(session.opponentCount)",
          value: $session.opponentCount,
          in: (Ruleset.minimumPlayerCount - 1)...(Ruleset.maximumPlayerCount - 1)
        )

        if let setupError = session.setupError {
          Text(setupError)
            .foregroundStyle(.red)
            .accessibilityLabel("Setup error: \(setupError)")
            .accessibilityFocused($isSetupErrorFocused)
        }
      } header: {
        Text("Players")
      } footer: {
        Text("Play against \(Ruleset.minimumPlayerCount - 1) to \(Ruleset.maximumPlayerCount - 1) computer opponents.")
      }
```

Then delete `PlayerDraft`, `playerDrafts`, `canAddPlayer`, `canRemovePlayer`, `addPlayer()`, `removePlayers(at:)` and `movePlayers(from:to:)` from `GameSession`. The `didSet` on `playerDrafts` that cleared `setupError` goes with it, so add the same clearing to `humanName` and `opponentCount`.

- [ ] **Step 2: Verify the name collision is gone**

Add:

```swift
@Test("Starting with the default name succeeds")
func defaultNameStartsCleanly() throws {
  let session = GameSession()
  #expect(session.start(with: .canonical))
  #expect(session.setupError == nil)
}
```

Run: `swift test -Xswiftc -warnings-as-errors --filter 'Flip7SessionTests.defaultNameStartsCleanly'`
Expected: PASS. A FAIL means `playerNames()` is still generating a name that collides with the human's.

- [ ] **Step 3: Run both Global Constraints commands, and launch on the iPhone and iPad simulators**

Expected: all green, a playable solo game from setup to final result.

- [ ] **Step 4: Commit and open the PR for #41**

```bash
git commit -am "feat: replace player setup with solo opponent selection"
```

Record in the PR body: Apple sources, Xcode and SDK versions, exact API availability for `Task.sleep(for:)` and `Duration`, the review range, findings or `None`, and both green checks.
