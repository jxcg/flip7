# MVP product contract

## Goal

Deliver a polished native iOS game that runs one complete base-rules match from player setup through a 200-point result.

## Working assumptions

- The first release is local pass-and-play on one iPhone or iPad.
- A game supports 3–9 named players.
- The app implements the base 94-card deck: number cards, score modifiers, Freeze, Flip Three, and Second Chance.
- The app owns dealing, legal choices, action targeting, scoring, round transitions, and victory detection.
- The interface is original and does not reproduce the commercial products card faces, logo, packaging, or copy.

The local-mode assumption is deliberately reversible. The rules engine must not know about SwiftUI, device handoff, bots, or networking.

## Product design principles

- Follow native iOS interaction and layout conventions and review the current [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) before implementation.
- Use standard navigation, sheets, and controls so they acquire the current system appearance automatically. Cards and the table are content and must not receive custom Liquid Glass effects.
- If custom Liquid Glass is functionally justified for a control, follow [Apple's adoption guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), guard every symbol at its exact availability, and preserve the same hierarchy and behavior with native iOS 18 controls. Group multiple custom glass views rendered together in one `GlassEffectContainer`.
- Keep the table visually restrained and original. Clear game state and legal actions matter more than ornament.
- Respect system light and dark appearances, use system text styles where possible, and keep interactive regions at least 44 by 44 points.
- Treat VoiceOver, Dynamic Type, non-color state cues, Increase Contrast, Reduce Transparency, Reduce Motion, and responsive interaction as correctness requirements.
- Prefer the smallest clear implementation and measure rendering before adding custom effects. Never trade correctness or clarity for fewer lines.

## Rules source

Implementation follows the publisher-maintained [Dized rules](https://rules.dized.com/game/dPDRM857TU-BFRF7LzGE0g/flip-7) for the base game. Rule interpretations and tested edge cases belong in the relevant GitHub issue and core tests so future sessions can reconstruct why behavior exists.

## MVP capabilities

1. Configure and reorder 3–9 players.
2. Play locally with private player handoffs.
3. Resolve the complete base deck and action-card edge cases.
4. Explain round scoring and cumulative standings.
5. Restore an interrupted game.
6. Support VoiceOver, Dynamic Type, sufficient contrast, and reduced motion.
7. Complete a rematch without recreating the roster.

## Non-goals

- Online multiplayer, accounts, matchmaking, and backend services
- Computer opponents
- Expansion or alternate-edition cards
- Monetization, analytics, and advertising
- Public App Store submission before branding rights are confirmed

## Owner decisions still required

1. Confirm local pass-and-play as the first release mode, or choose bots/online play before issue #5 begins.
2. Confirm whether this is a private prototype, a licensed product, or must receive an original public name before issue #10.
3. Confirm whether sound is desired before the final polish issue.
