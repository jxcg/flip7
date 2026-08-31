# Flip 7 — design language

**Status:** working reference, deliberately untracked and excluded via
`.git/info/exclude`. Nothing here is binding until it lands in a GitHub issue
with acceptance criteria.

**Owner decisions already made** (do not relitigate without a new decision):
quiet-native chrome with energy banked for key moments; typographic card faces;
iOS 26 Liquid Glass first with a plainer iOS 18 path; full 13-hue value ramp;
system blue accent; SF Pro + SF Rounded; iPhone portrait and dark mode are the
only layouts in scope for the first release.

---

## 1. Thesis

> Cards live at low chroma. The game's biggest moment is the only time the colour
> turns all the way up.

Flip 7 is a game of accumulating tension: every flip is either a step toward the
7-unique bonus or the duplicate that wipes your round. The interface should feel
calm and completely legible while that tension builds, then pay it off loudly and
briefly. Restraint is not the absence of personality here — it is what makes the
payoff land.

The design job in one line: **make "what busts me next?" answerable at a glance,
and make surviving it feel good.**

---

## 2. The four layers

Every view in the app belongs to exactly one layer. This is the spine of the
system; it resolves most material and colour questions before they get asked.

| Layer | Contents | Material | Motion |
|---|---|---|---|
| **Chrome** | toolbar, action bar, deck/turn indicator | Liquid Glass (iOS 26) → `.regularMaterial` (iOS 18) | morphs, never moves the layout |
| **Table** | player rows, standings, the Rail | solid system backgrounds, **never glass** | still |
| **Card** | the 94 cards | solid tinted surface, **never glass** | the flip, the shake, the bloom |
| **Moment** | bust, freeze, Flip 7, round tally | transient overlay, colour + motion only | the loud 400–1200 ms |

Cards never get glass. Glass cannot sample glass, dense numerals on a translucent
surface is the exact failure Apple calls out, and a card that borrows colour from
whatever is behind it destroys the value ramp's whole purpose.

---

## 3. Colour

### 3.1 The law

**Hue belongs to values. States are expressed with luminance, saturation and
motion — never a new hue on a card.**

Thirteen values consume nearly the whole colour wheel, so there is no free hue
left to mean "busted" or "frozen". Rather than fight that, states change how much
colour a card has:

| State | Card treatment |
|---|---|
| In hand | wash at rest chroma |
| Busted | drains to `0` neutral grey over 400 ms; red lives on the chrome, not the card |
| Frozen | washes toward white, chroma to 20%, hairline frost stroke |
| Second chance spent | the duplicate and the shield card both drain; the hand stays lit |
| Flip 7 | every card jumps from wash to **full chroma** — the only time it happens |

### 3.2 Core tokens

| Token | Light | Dark | Notes |
|---|---|---|---|
| `table` | `Color(.systemGroupedBackground)` | true black | OLED; tinted cards pop hardest on black |
| `surface` | `Color(.secondarySystemGroupedBackground)` | `Color(.secondarySystemGroupedBackground)` | player rows, sheets |
| `accent` | `#007AFF` | `#0A84FF` | system blue; interactive only, never decorative |
| `alert` | `Color(.systemRed)` | `Color(.systemRed)` | bust chrome, destructive actions |
| `frost` | `#EAF2F7` @ 88% | `#0E2029` @ 88% | freeze overlay; a treatment, not a hue |
| `ink` / `inkMuted` | `Color(.label)` / `.secondaryLabel` | same | all non-card text |

Six tokens, all but two of them semantic system colours. The identity is carried
by the ramp below, not by restyling iOS.

### 3.3 The value ramp

Generated and verified by `docs/palette_check.py`. Hues rotate monotonically red →
magenta and **skip 205–235°**, the lane reserved for the system-blue accent, so no
card ever reads as tappable. Value `0` is neutral: there is exactly one 0 card in
the deck, and colourlessness is the honest way to say "unique, worthless, safe".

Each value carries three roles:

- **wash** — the card surface. Low chroma. This is the resting state.
- **ink** — the numeral. Solved to ≥ **4.5:1** against its own wash in both
  modes. That is AAA: WCAG asks 4.5:1 of *large* text (≥ 18pt regular / 14pt
  bold) and the numeral is 44pt SF Rounded Black. The floor started at the
  7:1 normal-text figure, which forced washes so pale that neighbouring values
  were not tellable apart — the correct target buys back roughly double the
  wash chroma at no cost to compliance. `Increase Contrast` restores 7:1 (§3.4).
- **rail** — full chroma. Used only in the Rail (§5) and the 1pt card edge at 35%.

| Value | Hue | Wash (light) | Ink (light) | Ratio | ΔE | Wash (dark) | Ink (dark) | Ratio | ΔE | Rail L/D |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | neutral | `#DBDBDB` | `#5E5E5E` | 4.7 | - | `#424242` | `#B0B0B0` | 4.6 | - | `#7A7A7A` / `#858585` |
| 1 | 8 | `#F5C8C2` | `#AF240E` | 4.5 | 17.8 | `#67281E` | `#F88877` | 4.6 | 34.6 | `#D33A22` / `#E04129` |
| 2 | 26 | `#F5D8C2` | `#9C4B0D` | 4.5 | 10.7 | `#673D1E` | `#F7A15F` | 4.5 | 14.4 | `#D36F22` / `#E07829` |
| 3 | 42 | `#F5E6C2` | `#84600B` | 4.6 | 9.4 | `#67511E` | `#F5C147` | 4.5 | 14.8 | `#AF831D` / `#E0A929` |
| 4 | 55 | `#F5F1C2` | `#766D0A` | 4.6 | 7.3 | `#67611E` | `#F3E220` | 4.8 | 11.7 | `#958B18` / `#E0D129` |
| 5 | 78 | `#E6F5C2` | `#55760A` | 4.6 | 7.4 | `#51671E` | `#B4F320` | 4.8 | 13.6 | `#709518` / `#A9E029` |
| 6 | 105 | `#CEF5C2` | `#25760A` | 4.8 | 8.8 | `#30671E` | `#55F320` | 4.6 | 13.3 | `#3B9E1A` / `#57E029` |
| 7 | 142 | `#C2F5D4` | `#0A7631` | 4.7 | 9.9 | `#1E6739` | `#20F36E` | 4.6 | 14.8 | `#1A9E4A` / `#29E06C` |
| 8 | 168 | `#C2F5EB` | `#0A7660` | 4.7 | 12.0 | `#1E6758` | `#20F3C9` | 4.7 | 19.2 | `#1A9E83` / `#29E0BC` |
| 9 | 192 | `#C2EBF5` | `#0B6C84` | 4.7 | 11.5 | `#1E5867` | `#4CD4F6` | 4.6 | 21.1 | `#1D96B4` / `#29BCE0` |
| 10 | 252 | `#CCC2F5` | `#3912D9` | 5.6 | 30.3 | `#2C1E67` | `#9981F8` | 4.6 | 52.0 | `#4622D3` / `#5936E2` |
| 11 | 278 | `#E2C2F5` | `#8310C6` | 4.6 | 7.7 | `#4C1E67` | `#CB7CF8` | 4.6 | 10.6 | `#9222D3` / `#9D29E0` |
| 12 | 312 | `#F5C2EB` | `#A50D87` | 4.6 | 8.9 | `#671E58` | `#F877DE` | 4.6 | 16.7 | `#D322AF` / `#E029BC` |


Run `python3 docs/palette_check.py` after any ramp edit. It regenerates this
table and exits non-zero on any failure, so the ramp cannot quietly rot. It
enforces three things, not one:

1. **Ink ≥ 4.5:1** on its own wash, both modes.
2. **Rail ≥ 3:1** on the table — the non-text UI floor.
3. **Adjacent washes ≥ ΔE 5** — contrast ratio says nothing about hue, so two
   washes can both pass their floor and still be the same colour to a player.
   Only a perceptual distance metric catches that, and it is the check that
   would have caught the original ramp: it ran at ΔE 3.2 in its worst pair.

Card-vs-table separation is deliberately *not* a contrast check — a wash sits
between 1.03:1 and 1.49:1 against the light table on purpose. Separation comes
from the 1pt `rail` edge and the card's own shadow, never from luminance. The
ramp is intentionally uneven: yellow is intrinsically bright and violet
intrinsically dark, so the same floor costs each hue a different amount of
chroma, and value 10 overshoots to 5.6:1 because the 205–235° blue-lane skip
leaves a real gap in the sequence. Letting each hue land where it lands beats
clamping thirteen values down to whatever the worst one can manage.

### 3.4 Accessibility behaviour

- **Increase Contrast** → washes collapse to `surface`, ink to `Color(.label)`,
  and hue survives only in the edge stroke and the Rail. That restores 7:1 and
  better, which is the pairing `palette_check.py` asserts last.
- **Differentiate Without Colour** → nothing changes on cards; the numeral was
  always the primary signal. The Rail switches filled/hollow rather than hue-only.
- Hue is never load-bearing. Anything colour tells you, the numeral or the Rail's
  fill state tells you too.

---

## 4. Typography

Three faces, three jobs, zero downloads.

| Role | Face | Usage |
|---|---|---|
| **Numerals** | SF Rounded, Black | card faces only. Tabular figures, tracking −2%. The rounded terminals are the entire "toy" budget of the app. |
| **Interface** | SF Pro | every label, name, button and sentence. Sentence case, system sizes. |
| **Data** | SF Mono, Medium | deck count, score deltas, round number. Readouts that change, set as machine output. |

Rounded for the things you play with, Pro for the things you read, Mono for the
things you count. A player never has to wonder which kind of number they're
looking at.

**Scale.** Card numeral is `@ScaledMetric(relativeTo: .largeTitle) var numeral = 44`.
The card grows with the numeral rather than clipping it — Dynamic Type changes the
card size, never the type ratio. Above `.accessibility1` the hand reflows from a
row to a two-column grid. Player names `.body` semibold, scores `.body` monospaced
digits, deck count `.footnote` in SF Mono.

---

## 5. The Rail — signature element

A 13-segment track under the active hand. One segment per value, `0` on the left
through `12` on the right. Collected values are filled at `rail` chroma; the rest
are hollow at 12% ink.

```
  0  1  2  3  4   5   6    7    8     9     10     11     12
  ░░ ░░ ░░ ██ ░░░ ░░░ ░░░░ ████ ░░░░░ ░░░░░ ░░░░░░ ██████ ░░░░░░░
  █ held    ░ still out there    width = copies in a fresh deck
```

*(sketch — widths halved to fit the page; the real formula is below)*

**Segment width is proportional to how many copies of that value exist in the
deck** — one 1, two 2s, twelve 12s. The Rail is therefore a wedge, thin on the
left and wide on the right, and its shape *is* the risk curve of Flip 7. The wide
segments are the ones likely to bust you. Nobody has to explain that; the geometry
says it.

Width: `segment = 8 + 3 × copies` (0 counts as 1 copy). Across the 13 segments
that's `13 × 8 + 79 × 3 = 341pt`, which fits the content width of every supported
iPhone. Value 1 renders 11pt wide, value 12 renders 44pt.

The Rail also **replaces a separate Flip-7 progress meter**: seven filled segments
*is* the bonus, so the count, the identity of the held values, and the odds all
live in one component instead of three.

**Motion.** Each flip wipes the drawn value's segment left-to-right in 180 ms. A
bust double-flashes the duplicate's segment, then drains the whole Rail to grey.
Flip 7 blooms the seven filled segments to full chroma, and the hand follows 80 ms
behind.

**VoiceOver.** One element, not thirteen: *"Rail. Holding 3, 7 and 11. Four more
unique numbers for Flip 7."*

This is the one deliberate risk in the design — permanent probability furniture in
a casual party game. It is justified because it answers the only question a player
actually asks each turn, and because it makes the 13-hue ramp load-bearing
information rather than decoration.

---

## 6. Card anatomy

- Aspect 5:7, corner radius 14pt, 1pt `rail` edge at 35%, shadow y2 blur6 at 8%.
  Draw that shadow as `.shadow(.drop(...))` inside the fill's `ShapeStyle`, not as
  a `.shadow()` view modifier — identical result, drawn in the shape's own pass
  instead of an offscreen blur per card (§11).
- Numeral centred, optically not mathematically — nudged up 2% of card height.
- **Number cards** carry their wash and nothing else. No pips, no icon, no corner
  index. The numeral is the artwork.
- **Action cards** deliberately break the ramp so a Freeze can never be misread as
  a number: inverted surface (`ink` fill, `table` symbol), SF Symbol plus a
  sentence-case label.
  - Freeze → `snowflake`
  - Flip Three → `arrow.trianglehead.2.clockwise`
  - Second Chance → `shield.lefthalf.filled`
- **Modifier cards** are a third class: `surface` fill, ink numeral in SF Rounded
  with an explicit `+` or `×`, hairline dashed edge. They are neither values nor
  actions and should not look like either.

---

## 7. Layout — iPhone portrait

```
┌───────────────────────────────────────┐
│  Round 2                      61 ⌗    │ ← chrome: glass toolbar
├───────────────────────────────────────┤
│                                       │
│    ╭─────╮  ╭─────╮  ╭─────╮          │ ← active hand, washes
│    │  7  │  │  3  │  │ 11  │          │   SF Rounded Black
│    ╰─────╯  ╰─────╯  ╰─────╯          │
│                                       │
│   ▕▏▕▏▕▁▏▕■▏▕▁▁▏▕▁▁▁▏▕■▏▕▁▁▏▕■▏…      │ ← the Rail
│                                       │
│    Josh                    38 pts     │
├───────────────────────────────────────┤
│    Amara      ●●●●        42   Stayed │ ← opponents: compact rows,
│    Ben        ●●          19   Busted │   hue dots not full cards
│    Priya      ●●●         31          │
├───────────────────────────────────────┤
│      ╭─────────╮  ╭───────────────╮   │ ← glass action bar,
│      │  Stay   │  │      Hit      │   │   thumb zone, .glassProminent
│      ╰─────────╯  ╰───────────────╯   │
└───────────────────────────────────────┘
```

- Spacing scale 4/8/12/16/24/32. Content inset 16pt.
- Concentric radii: chrome container 22, card 14, nested inset 8 (child = parent − inset).
- The active player owns the top two-thirds; opponents compress to one row each so
  nine players still fit without scrolling the active hand off-screen.
- Opponent hands are hue dots in draw order — enough to see someone is at five
  unique numbers and closing, not enough to compete with your own hand.
- Action bar sits in the thumb arc. Hit is `.glassProminent`; Stay is `.glass`.
  Hit is on the right because it is the repeated action.

**Turn handoff.** Worth noting: Flip 7 has no hidden information — every card is
face up. The handoff screen is a *turn gate*, not a privacy veil, and should not
blank the table. `MVP.md` calls these "private player handoffs"; the honest design
is a full-width sheet reading "Amara's turn" with a single "I'm Amara" button, the
table dimmed but visible behind it. Flag this wording for the owner.

---

## 8. Motion

Every motion has a Reduce Motion equivalent that is a 200 ms cross-fade with no
translation, rotation or shake. No exceptions, including the celebration.

| Moment | Motion | Duration |
|---|---|---|
| Deal | staggered rise + fade, 50 ms apart | 300 ms |
| Flip | `.spring(response: 0.34, dampingFraction: 0.72)`, Y-rotation 180° + 4pt rise | ~340 ms |
| Rail fill | left-to-right wipe on the drawn segment | 180 ms |
| Stay | card set settles 2pt and desaturates 15% | 220 ms |
| Bust | 3-cycle shake, 6pt amplitude, then drain to neutral | 280 + 400 ms |
| Freeze | frost wipe top-to-bottom across the hand | 500 ms |
| Second chance | shield card slides over the duplicate, both drain | 400 ms |
| **Flip 7** | chroma bloom across hand and Rail, outward from the seventh card | 450 ms |
| Round tally | SF Mono count-up, ease-out, per-player stagger | 600 ms |

Nothing exceeds 500 ms except the tally. The loud moments are loud because they
are surrounded by stillness, not because they are long.

**All motion is event-driven and one-shot.** Nothing loops, ever — see the idle
rule in §11, which is the same statement made about power rather than taste.

---

## 9. Feedback director

`Flip7Core` already emits exactly the right events. `GameEvent` is the feedback
bus — a single `FeedbackDirector` consumes the event stream and fires motion,
haptics and sound. SwiftUI stays a renderer, the core stays ignorant of all three.

| `GameEvent` | Haptic (`.sensoryFeedback`) | Sound | Motion |
|---|---|---|---|
| `cardDrawn` (number) | `.impact(weight: .light, intensity: 0.5)` | flip tick | flip + rail fill |
| `cardDrawn` (action/modifier) | `.impact(weight: .medium, intensity: 0.7)` | flip tick | flip |
| `secondChanceGranted` | `.impact(flexibility: .soft)` | — | card settles |
| `secondChanceUsed` | `.warning` | — | shield slide |
| `playerStayed` | `.selection` | — | settle + desaturate |
| `playerBusted` | `.error` | — | shake + drain |
| `flipSeven` | `.success`, then `.impact(.heavy)` 120 ms later | *needs custom asset* | chroma bloom |
| `roundEnded` | `.levelChange` | — | tally count-up |
| `gameEnded` | `.success` | — | standings reveal |
| turn handoff | `.selection` | — | sheet |

The two-beat on `flipSeven` (success, pause, heavy impact) is the only compound
haptic in the app. It is the physical equivalent of the chroma bloom.

### Sound — read this before implementing

Constrained to system sounds for now, per owner instruction. Findings:

- `AudioServicesPlaySystemSound(1104)` (the keyboard tock) is genuinely good as a
  flip confirmation. That is the one worth shipping.
- Every other candidate is wrong. The recognisable system sounds are communication
  sounds — mail, SMS, voicemail — and a player who hears the SMS chime when they
  bust will look for a message. Borrowing them is worse than silence.
- The IDs are undocumented, cannot be volume-tuned, and ignore the app's own
  audio session. They are a placeholder, not an identity.

**Recommendation:** ship v1 with haptics carrying the feel, one system tick on
flip, and a Sound toggle in settings defaulting to on. Bust, freeze and Flip 7 are
haptic-only until custom audio exists.

**Flagged for the owner:** a real sound identity needs five short custom assets —
flip, stay, bust, freeze, Flip 7. That answers open MVP decision #3 and should
become its own issue. No audio was fetched.

---

## 10. Liquid Glass posture

**Glass on:** toolbar, bottom action bar, the floating deck/turn indicator.
**Glass never on:** cards, table, standings, any dense text, anything scrolling.

That first list is the set that obviously earns glass, **not a ceiling**. Glass is
a hierarchy signal, not a finish and not a budget — the test for anything new is
*does this element float above the table, or is it part of the table?* Floating
chrome gets glass and the app should read as properly iOS 26; table content never
does. Under-glassing reads as an iOS 18 app wearing a hat, which is the worse
failure. Cost tracks glass **area and sampling passes**, not surface count (§11),
so a fourth small floating control is close to free, while one full-bleed glass
panel is not — and a wall of glass reads as a filter over the app rather than a
material in it.

- `.buttonStyle(.glassProminent)` for Hit, `.buttonStyle(.glass)` for Stay.
- Wrap the action bar in a `GlassEffectContainer` so the two buttons share one
  sampling pass and morph together when the available actions change.
- Reach for `.glassEffect()` directly only for the deck indicator, which is not a
  button.
- Never nest glass in glass.

**One availability shim.** `if #available(iOS 26, *)` should appear exactly once
in the app, inside a `chromeSurface()` `ViewModifier`. iOS 18 renders the same
geometry and radii in `.regularMaterial` with a 1pt hairline. The layout is
identical in both; only the material differs. Thirteen scattered availability
checks is how this design language dies.

**Reduce Transparency** collapses both paths to an opaque `surface` fill. **Low
Power Mode** does the same — glass is the first thing to go.

---

## 11. Performance and energy

Glass stays and the design does not get quieter to save battery. This section
exists so the loud parts stay affordable, not to trim them. The public evidence on
Liquid Glass drain is genuinely mixed — near-free on A18-class silicon, measurable
on older hardware, with screen brightness dominating either way — so everything
below is a structural rule plus an on-device gate, never an invented milliwatt
target.

**The one absolute: an idle table renders zero frames.**

Pass-and-play is mostly a human thinking. Any `repeatForever`, `TimelineView` or
`Timer`-driven animation holds the display out of its idle low-refresh state for
the entire think-time, and that one decision outweighs every other item here. It
also costs the design nothing, because §1 already says the table is still between
moments.

- Banned: `repeatForever`, `TimelineView` on the table, `Timer`-driven animation,
  ambient gradients, breathing glows.
- The active-player cue is **static** — tint, weight, border. If it needs motion,
  one shot ≤ 600 ms on turn change, then fully at rest.

**Glass is priced by area and sampling passes, not by surface count.**

- Cluster glass elements into one `GlassEffectContainer`: six buttons in one
  container is both cheaper and better-looking than three standalone surfaces,
  because that is what lets them morph into each other.
- What actually costs: full-bleed glass panels, glass over scrolling content,
  animated tints, glass on cards. All four are already banned in §10 for design
  reasons — the perf argument is a coincidence, not the motivation.

**The card layer is where frames go.**

- Only the active hand renders real card views (§7). Opponents are compact rows of
  hue dots, which caps on-screen cards near 15 rather than 60+ at nine players.
  That was a legibility decision first; it happens to be the whole render budget.
- A card is a filled rounded rect, a 1pt stroke and a numeral. Depth comes from
  `.shadow(.drop(...))` inside the fill (§6), never a per-card `.shadow()` view
  modifier — 15 offscreen blur passes per frame buys nothing visible.
- `LazyHStack` for long hands. `ForEach` keyed on the existing `GameCard.id` so a
  flip animates one card instead of rebuilding the row.

**Motion budget.** `.animation(_:value:)` scoped to the smallest view that
changes, never the table root — a blanket animation re-diffs the whole tree on
every draw. The Flip 7 bloom is a fixed-count scale/opacity burst across the hand
and Rail, not a particle emitter.
`// ponytail: fixed-count burst; swap for an emitter only if it reads flat on device.`

**One fallback, three payoffs.** The iOS 18 solid-material path, Reduce
Transparency, and Low Power Mode all collapse to the same rendering — build it
once for iOS 18 and the other two are free, roughly ten lines behind the
`chromeSurface()` modifier from §10. Low Power Mode also caps the display at
60 Hz, so this path is what a drained-battery player actually sees: it has to look
deliberate, not degraded. Dark mode on OLED is a real saving on top, which is why
`table` is true black rather than a lifted grey.

**State plumbing.** `Flip7Core` is already value types. Expose derived slices from
one `@Observable` view model so a card view receives a `GameCard` and two
booleans, never the whole `GameState` — a draw should invalidate one row, not the
table. The `FeedbackDirector` (§9) is event-driven off `GameEvent`; nothing polls.

**Verification gates.** Add these to the issue template beside `swift test`, on any
issue that touches UI:

1. Instruments **Animation Hitches** over a full 9-player round → zero hitches.
2. Core Animation **FPS gauge** on an untouched table → **0 frames**.
3. Instruments **Energy Log** → no sustained "High" impact while idle.
4. Run on a real device at the iOS 18 floor (iPhone XR/11 class). The simulator
   hides GPU cost entirely, so a simulator-only pass proves nothing here.

---

## 12. Accessibility contract

Treated as correctness, per `MVP.md`, not as a polish pass.

- Every card is one accessibility element: *"Seven. Third card."* New cards
  announce via `AccessibilityNotification.Announcement`.
- Bust, freeze and Flip 7 post announcements — a VoiceOver player must never learn
  they busted only from the score.
- The Rail is one element with a summarising label (§5).
- Dynamic Type to AX5; hand reflows to a grid above `.accessibility1`.
- All contrast floors are enforced by `palette_check.py`, not by eye.
- Hit targets ≥ 44pt. The action bar never overlaps the home indicator.
- Reduce Motion, Reduce Transparency, Increase Contrast and Differentiate Without
  Colour all have defined behaviour above.

---

## 13. What was cut

- **A separate 7-pip Flip 7 meter.** The Rail already carries the count. Two
  components saying the same thing is one too many.
- **Felt and wood table textures.** They belong to the toy-tabletop direction that
  was considered and rejected; simulated materials under Liquid Glass chrome reads
  as two apps stacked.
- **A celebratory gold for Flip 7.** Colour law: states don't get hues. The bloom
  to full chroma is stronger anyway, because it spends colour the design has been
  saving the entire round.
- **Full opponent hands on screen.** Nine hands of cards is a spreadsheet. Hue dots
  plus a score is what a player actually scans for.

---

## 14. Deferred — file as GitHub issues

1. iPad shared-table layout (a tablet flat on a table is a different design
   problem, possibly multi-orientation card faces).
2. iPhone landscape.
3. Five custom sound assets (§9) — also resolves open MVP decision #3.
4. App icon and wordmark. Blocked on the naming/licensing decision in `MVP.md`.
5. Live deck-remaining widths on the Rail. v1 uses static deck composition, which
   is public information printed on the box; live counts edge toward a play aid
   and need an owner decision.
