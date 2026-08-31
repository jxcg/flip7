import SwiftUI

#if SWIFT_PACKAGE
  import Flip7Core
#endif

struct ContentView: View {
  @State private var session = GameSession()
  @State private var isShowingSession = false

  var body: some View {
    NavigationStack {
      NewGameView(session: session) {
        if session.start() {
          isShowingSession = true
        }
      }
      .navigationDestination(isPresented: $isShowingSession) {
        GameTableView(session: session)
      }
      .onChange(of: isShowingSession) { _, isShowing in
        if !isShowing {
          session.resetGame()
        }
      }
    }
  }
}

private struct NewGameView: View {
  @Bindable var session: GameSession
  @AccessibilityFocusState private var isSetupErrorFocused: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let startGame: () -> Void

  /// A hand rather than a wordmark. The app has no approved name yet, so the
  /// cards carry the identity: this is the value ramp, which is the whole
  /// visual argument of the game.
  private let heroValues: [NumberValue] = [.three, .seven, .eleven]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 24) {
          hero
          form
          rules
        }
        .padding(.bottom, 16)
      }
      .scrollBounceBehavior(.basedOnSize)

      start
    }
    .background(TablePalette.table)
    .navigationTitle("New game")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: session.setupError) { _, error in
      isSetupErrorFocused = error != nil
    }
  }

  private var hero: some View {
    HStack(spacing: -18) {
      ForEach(Array(heroValues.enumerated()), id: \.offset) { index, value in
        CardView(card: GameCard(id: CardID(rawValue: index), kind: .number(value)))
          .rotationEffect(.degrees(Double(index - 1) * 8))
          .offset(y: index == 1 ? -8 : 0)
      }
    }
    .padding(.top, 12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Flip 7")
  }

  private var form: some View {
    VStack(spacing: 0) {
      field(label: "Your name") {
        TextField("You", text: $session.humanName)
          .multilineTextAlignment(isStacked ? .leading : .trailing)
          .textContentType(.name)
          .submitLabel(.done)
      }
      .padding(.vertical, 14)
      .accessibilityLabel("Your name")

      Divider().overlay(Color(.separator))

      Stepper(value: $session.opponentCount, in: opponentRange) {
        field(label: "Opponents") {
          Text("\(session.opponentCount)")
            .monospacedDigit()
            .frame(maxWidth: isStacked ? .infinity : nil, alignment: .leading)
        }
      }
      .padding(.vertical, 8)

      if let setupError = session.setupError {
        Divider().overlay(Color(.separator))
        Text(setupError)
          .font(.footnote)
          .foregroundStyle(Color(.systemRed))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 12)
          .accessibilityLabel("Setup error: \(setupError)")
          .accessibilityFocused($isSetupErrorFocused)
      }
    }
    .padding(.horizontal, 16)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(TablePalette.surface)
    )
    .padding(.horizontal, 16)
  }

  private var rules: some View {
    Text(
      "Draw numbers to build a score. Stay to bank it. A repeated number "
        + "busts you unless Second Chance saves you. First to "
        + "\(Ruleset.targetScore) wins."
    )
    .font(.footnote)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
    .padding(.horizontal, 16)
  }

  private var start: some View {
    Button {
      startGame()
    } label: {
      Text("Start game")
        .frame(maxWidth: .infinity, minHeight: 50)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .chromeSurface()
  }

  /// Side by side normally; stacked once the text is large enough that a row
  /// would truncate the label.
  private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

  @ViewBuilder
  private func field(label: String, @ViewBuilder value: () -> some View) -> some View {
    if isStacked {
      VStack(alignment: .leading, spacing: 6) {
        Text(label)
        value()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      LabeledContent(label) { value() }
    }
  }

  private var opponentRange: ClosedRange<Int> {
    (Ruleset.minimumPlayerCount - 1)...(Ruleset.maximumPlayerCount - 1)
  }
}

#Preview {
  ContentView()
}
