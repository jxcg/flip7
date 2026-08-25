# Architecture

## Boundaries

```text
SwiftUI views
    -> presentation/session model
        -> Flip7Core commands
            -> immutable game state + emitted events
```

`Flip7Core` is a Swift Package compiled independently of the app. It owns card identity, deck order, commands, legal targets, game state, rule invariants, and scoring. It imports no SwiftUI types and accepts injected deck order so every transition can be reproduced in tests.

The app target owns navigation, device handoff, animation, haptics, accessibility wording, and persistence orchestration. Views display engine state and send commands; they do not duplicate rules.

## State evolution

- A command is accepted only when legal for the current state.
- An accepted command produces the next complete state and semantic events for presentation.
- A pending choice, such as selecting an action-card target, is explicit state rather than an alert-only callback.
- Saved games encode versioned engine state, never view hierarchy or animation state.
- Randomness enters only through a shuffled deck supplied when a deck is created or recycled.

## Quality gates

- Core behavior is covered by deterministic Swift tests.
- Every fixed rule regression gains a focused test.
- The app must build for a generic iOS Simulator without code signing.
- UI smoke tests cover the critical path after the interface exists.
