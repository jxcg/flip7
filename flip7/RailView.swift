import SwiftUI

#if SWIFT_PACKAGE
  import Flip7Core
#endif

/// A thirteen-segment track under the active hand, one segment per value.
///
/// Segment width is proportional to how many copies of that value exist in the
/// deck: one 1, two 2s, twelve 12s. The Rail is therefore a wedge, and its
/// shape *is* the risk curve of the game. The wide segments on the right are
/// the ones likely to bust you, and nobody has to be told that.
///
/// It also replaces a separate Flip 7 meter. Seven filled segments *is* the
/// bonus, so the count, which values are held, and the odds live in one
/// component instead of three.
struct RailView: View {
  let held: Set<NumberValue>

  private var values: [NumberValue] { NumberValue.allCases }

  var body: some View {
    GeometryReader { proxy in
      let widths = segmentWidths(in: proxy.size.width)
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
          Capsule(style: .continuous)
            .fill(
              held.contains(value)
                ? CardPalette.rail(for: value.rawValue)
                : Color(.label).opacity(0.12)
            )
            .frame(width: widths[index], height: 10)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .frame(height: 16)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityDescription)
  }

  /// `8 + 3 * copies` at the design width, scaled to whatever width it gets.
  private func segmentWidths(in available: Double) -> [Double] {
    let raw = values.map { 8 + 3 * Double(max($0.rawValue, 1)) }
    let spacing = 2 * Double(values.count - 1)
    let total = raw.reduce(0, +)
    let scale = max(available - spacing, 1) / total
    return raw.map { $0 * scale }
  }

  private var accessibilityDescription: String {
    guard !held.isEmpty else {
      return "Rail. No numbers held."
    }
    let numbers = held.map(\.rawValue).sorted().map(String.init)
    let remaining = Ruleset.flipSevenNumberCount - held.count
    let holding = numbers.count == 1
      ? numbers[0]
      : numbers.dropLast().joined(separator: ", ") + " and " + numbers[numbers.count - 1]
    if remaining <= 0 {
      return "Rail. Holding \(holding). Seven unique numbers reached."
    }
    return "Rail. Holding \(holding). "
      + "\(remaining) more unique \(remaining == 1 ? "number" : "numbers") for Flip 7."
  }
}
