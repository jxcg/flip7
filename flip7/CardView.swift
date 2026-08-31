import SwiftUI

#if SWIFT_PACKAGE
  import Flip7Core
#endif

/// A single card face.
///
/// Three classes, deliberately different so they can never be misread for one
/// another. A number card is its numeral and nothing else; the numeral is the
/// artwork. An action card inverts the surface so a Freeze can never scan as a
/// number. A modifier is a third thing again, and should not look like either.
/// How a card is reading right now.
///
/// States change how much colour a card has, never its hue. Thirteen values
/// already consume nearly the whole wheel, so there is no free hue left to mean
/// "busted" or "frozen".
enum CardState {
  case inHand
  /// Busted, or a Second Chance spent. Drains to neutral; red lives on the
  /// chrome, never on the card.
  case drained
  /// Frozen. Washes toward white with a hairline frost stroke.
  case frosted
}

struct CardView: View {
  let card: GameCard
  var state: CardState = .inHand

  /// The card grows with the numeral rather than clipping it, so Dynamic Type
  /// changes the card size and never the type ratio.
  @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: Double = 44
  @Environment(\.legibilityWeight) private var legibilityWeight
  @Environment(\.colorSchemeContrast) private var contrast

  private var height: Double { numeralSize * 2 }
  private var width: Double { height * 5 / 7 }

  var body: some View {
    face
      .frame(width: width, height: height)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            surface.shadow(.drop(color: .black.opacity(0.08), radius: 6, y: 2))
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(edge, style: edgeStyle)
      )
      .saturation(saturation)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.white.opacity(state == .frosted ? 0.5 : 0))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(
            Color.white.opacity(state == .frosted ? 0.7 : 0),
            lineWidth: 1
          )
      )
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityName)
  }

  private var saturation: Double {
    switch state {
    case .inHand: 1
    case .drained: 0
    case .frosted: 0.2
    }
  }

  /// Meaning never depends on colour alone, so the state is spoken too.
  private var accessibilityName: String {
    switch state {
    case .inHand: card.displayName
    case .drained: "\(card.displayName), out of play"
    case .frosted: "\(card.displayName), frozen"
    }
  }

  @ViewBuilder
  private var face: some View {
    switch card.kind {
    case .number(let value):
      // Under Increase Contrast the wash collapses, so the numeral takes the
      // full-strength label colour and hue survives only in the edge and Rail.
      numeral(
        "\(value.rawValue)",
        tint: contrast == .increased ? Color(.label) : CardPalette.ink(for: value.rawValue)
      )
    case .scoreModifier(.additive(let bonus)):
      numeral("+\(bonus.rawValue)", tint: Color(.label))
    case .scoreModifier(.double):
      numeral("×2", tint: Color(.label))
    case .action(let action):
      actionFace(action)
    }
  }

  private func numeral(_ text: String, tint: Color) -> some View {
    Text(text)
      .font(.system(size: numeralSize, weight: .black, design: .rounded))
      .monospacedDigit()
      .tracking(numeralSize * -0.02)
      .minimumScaleFactor(0.5)
      .foregroundStyle(tint)
      // Optically centred, not mathematically: nudged up 2% of card height.
      .offset(y: height * -0.02)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func actionFace(_ action: ActionCard) -> some View {
    VStack(spacing: 4) {
      Image(systemName: card.systemImage)
        .font(.system(size: numeralSize * 0.5, weight: .semibold))
      Text(actionLabel(action))
        .font(.caption2.weight(.semibold))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
    }
    .foregroundStyle(Color(.systemBackground))
    .padding(4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func actionLabel(_ action: ActionCard) -> String {
    switch action {
    case .freeze: "Freeze"
    case .flipThree: "Flip three"
    case .secondChance: "Second chance"
    }
  }

  private var surface: Color {
    switch card.kind {
    case .number(let value):
      contrast == .increased
        ? Color(.secondarySystemGroupedBackground)
        : CardPalette.wash(for: value.rawValue)
    case .scoreModifier:
      Color(.secondarySystemGroupedBackground)
    case .action:
      // Inverted, so an action can never be mistaken for a value.
      Color(.label)
    }
  }

  /// Modifiers carry a dashed edge. Without it a modifier and the neutral 0
  /// card are both grey rectangles and read as the same thing.
  private var edgeStyle: StrokeStyle {
    if case .scoreModifier = card.kind {
      return StrokeStyle(lineWidth: 1, dash: [4, 3])
    }
    return StrokeStyle(lineWidth: 1)
  }

  private var edge: Color {
    switch card.kind {
    case .number(let value):
      // Separation comes from this edge and the card's own shadow, never from
      // luminance: a wash sits close to the table on purpose.
      // Hue is never load-bearing, but it is the only thing left carrying value
      // identity alongside the numeral once the wash collapses, so it goes to
      // full strength rather than 35%.
      CardPalette.rail(for: value.rawValue)
        .opacity(contrast == .increased || legibilityWeight == .bold ? 1 : 0.35)
    case .scoreModifier:
      Color(.label).opacity(0.45)
    case .action:
      Color.clear
    }
  }
}

#Preview("Cards") {
  let samples: [CardKind] = [
    .number(.zero), .number(.three), .number(.seven), .number(.twelve),
    .scoreModifier(.additive(.ten)), .scoreModifier(.double),
    .action(.freeze), .action(.flipThree), .action(.secondChance),
  ]
  return ScrollView(.horizontal) {
    HStack(spacing: 12) {
      ForEach(Array(samples.enumerated()), id: \.offset) { index, kind in
        CardView(card: GameCard(id: CardID(rawValue: index), kind: kind))
      }
    }
    .padding()
  }
}
