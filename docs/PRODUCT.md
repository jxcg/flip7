# Complete product contract

## Goal

Deliver a polished, complete native iOS game that implements the full approved rules and provides a fully featured experience in every owner-approved play mode.

## Current foundation

- Local pass-and-play on one iPhone or iPad is the first implemented mode, not a ceiling on the complete product.
- A game supports 3–9 named players.
- The app implements the base 94-card deck: number cards, score modifiers, Freeze, Flip Three, and Second Chance.
- The app owns dealing, legal choices, action targeting, scoring, round transitions, and victory detection.
- The interface is original and does not reproduce the commercial product's card faces, logo, packaging, or copy.
- Issue #19 decides the complete set of play modes, product identity, settings, continuity features, languages, privacy behavior, and distribution requirements. No capability is silently excluded.

The rules engine remains independent of SwiftUI, device handoff, computer opponents, and networking so every approved mode can share one deterministic rules implementation.

## Product design principles

- Follow native iOS interaction and layout conventions and review the current [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) before implementation.
- Use standard navigation, sheets, and controls so they acquire the current system appearance automatically. Cards and the table are content and must not receive custom Liquid Glass effects.
- If custom Liquid Glass is functionally justified for a control, follow [Apple's adoption guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), guard every symbol at its exact availability, and preserve the same hierarchy and behavior with native iOS 18 controls. Group multiple custom glass views rendered together in one `GlassEffectContainer`.
- Keep the table visually restrained and original. Clear game state and legal actions matter more than ornament.
- Respect system light and dark appearances, use system text styles where possible, and keep interactive regions at least 44 by 44 points.
- Treat VoiceOver, Dynamic Type, non-color state cues, Increase Contrast, Reduce Transparency, Reduce Motion, and responsive interaction as correctness requirements.
- Prefer the smallest clear implementation and measure rendering before adding custom effects. Never trade correctness or clarity for fewer lines.

## Rules source

Issue #19 selects one authoritative rules edition because the publisher-maintained [Dized rules](https://rules.dized.com/game/dPDRM857TU-BFRF7LzGE0g/flip-7) and the original 2024 rules conflict on disputed edge cases. Issue #4 must not encode those disputed behaviors until the owner records that decision. Rule interpretations and tested edge cases belong in the relevant GitHub issue and core tests so future sessions can reconstruct why behavior exists.

## Complete first-release capabilities

1. Onboard players, explain the rules, and configure reusable 3–9-player rosters.
2. Play the complete game in every mode approved by issue #19, beginning with private local handoffs.
3. Resolve the full approved deck, every action-card edge case, and every end-game condition.
4. Explain legal choices, action cards, round scoring, cumulative standings, and final results.
5. Restore interrupted games safely and manage saved sessions without losing or corrupting state.
6. Support VoiceOver, Dynamic Type, non-color cues, sufficient contrast, reduced transparency, and reduced motion throughout every flow.
7. Provide settings, help, tutorial, sound, haptics, history, and player statistics as approved in issue #19.
8. Complete rematches without recreating the roster.
9. Meet measurable correctness, performance, memory, energy, privacy, and accessibility release gates.
10. Provide a complete beta, support, update, migration, rollback, and App Store delivery path when public distribution is approved.

These capabilities are a baseline, not a ceiling. Every additional approved capability receives a focused GitHub issue with measurable acceptance criteria.

## Owner decisions required by issue #19

1. Choose the authoritative rules edition.
2. Choose local, computer-opponent, private-online, and public-matchmaking modes.
3. Confirm whether this is a licensed product or requires an original public name and presentation.
4. Choose sound, haptics, settings, tutorial, reusable rosters, history, and statistics.
5. Choose supported devices, orientations, languages, and cloud continuity.
6. Choose privacy, analytics, advertising, purchases, support, beta, and public-distribution requirements.
