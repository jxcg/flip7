# Complete product contract

## Goal

Deliver a polished, complete native iOS game that implements the full approved rules and provides a fully featured experience in every owner-approved play mode.

## Product foundation

- Solo play against computer opponents is the only mode the interface offers for the first release. Local pass-and-play is owner-declined as of 31 August 2026, superseding the earlier decision in #19 and the handoff work shipped in #5 and #7.
- Nearby-device play will be studied without a hosted server when two owner-approved physical devices are available. Shipping it remains a later decision based on that evidence.
- Private internet games and public matchmaking are scheduled later and do not block the first release.
- A complete base game will support 3–9 named players.
- The rules implementation will cover the approved 94-card deck: number cards, score modifiers, Freeze, Flip Three, and Second Chance.
- The app will own dealing, legal choices, action targeting, scoring, round transitions, and victory detection.
- `Flip7` is the private repository working title. The repository and internal code names remain unchanged unless separately approved.
- The final app name is deferred to release work in issue #10. The gameplay mechanics remain unchanged.
- The interface, artwork, card faces, logo, packaging, and wording must be original. Commercial assets and copy will not be used.
- Issue #19 records application and product choices. Issue #10 owns final app naming and release execution.

The rules engine remains independent of SwiftUI, computer opponents, and networking so every approved mode can share one deterministic rules implementation. It keeps its 3 to 9 seat support even though the interface now seats one human, so removing pass-and-play costs nothing in #24.

## Product design principles

- Follow native iOS interaction and layout conventions and review the current [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) before implementation.
- Use standard navigation, sheets, and controls so they acquire the current system appearance automatically. Cards and the table are content and must not receive custom Liquid Glass effects.
- If custom Liquid Glass is functionally justified for a control, follow [Apple's adoption guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), guard every symbol at its exact availability, and preserve the same hierarchy and behavior with native iOS 18 controls. Group multiple custom glass views rendered together in one `GlassEffectContainer`.
- Keep the table visually restrained and original. Clear game state and legal actions matter more than ornament.
- Respect system light and dark appearances, use system text styles where possible, and keep interactive regions at least 44 by 44 points.
- Treat VoiceOver, Dynamic Type, non-color state cues, Increase Contrast, Reduce Transparency, Reduce Motion, and responsive interaction as correctness requirements.
- Prefer the smallest clear implementation and measure rendering before adding custom effects. Never trade correctness or clarity for fewer lines.

## Rules source

Issue #19 records the owner's authoritative-rules choice because the publisher-maintained [Dized rules](https://rules.dized.com/game/dPDRM857TU-BFRF7LzGE0g/flip-7) and the original 2024 rules conflict on disputed edge cases. Issue #4 implements that choice and records its interpretations as tested behavior so future sessions can reconstruct why the behavior exists.

## Complete-release gate

The first release is complete only when:

1. Every decision named in issue #19 has an owner-recorded disposition and rationale.
2. Every included capability has a focused GitHub issue with measurable acceptance criteria, and every such issue is complete.
3. Players can finish the complete game in every approved mode.
4. The full selected rules contract, every card interaction, and every end-game condition are implemented and tested.
5. Onboarding, legal choices, action cards, scoring, standings, and final results are understandable without external instructions.
6. Interrupted games restore safely without lost or corrupted state.
7. Every flow meets its VoiceOver, Dynamic Type, non-color cue, contrast, transparency, and motion requirements.
8. Rematches preserve the approved player and game configuration.
9. Measurable correctness, performance, memory, energy, privacy, and accessibility gates pass.
10. Release checks include support, updates, migrations, and rollback evidence.

## Decision ownership

- Issue #19 owns rules authority, play modes, player experience, supported devices and languages, saving, cloud continuity, privacy, business, and external support.
- Issue #10 owns final app naming, release execution, and clearance.
