import SwiftUI

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
  let startGame: () -> Void

  var body: some View {
    Form {
      Section {
        TextField("Your name", text: $session.humanName)
          .textContentType(.name)
          .accessibilityLabel("Your name")

        Stepper(
          "Computer opponents: \(session.opponentCount)",
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
        Text(
          "Play against \(Ruleset.minimumPlayerCount - 1) to "
            + "\(Ruleset.maximumPlayerCount - 1) computer opponents."
        )
      }

      Section("How to Play") {
        Text(
          "Draw number cards to build your score. Stay to leave the "
            + "round safely. A repeated number can bust you unless "
            + "Second Chance saves you. After a round, a unique "
            + "leader with at least \(Ruleset.targetScore) points wins."
        )
      }

      Section {
        Button("Start Game", action: startGame)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
    }
    .navigationTitle("New Game")
    .onChange(of: session.setupError) { _, error in
      isSetupErrorFocused = error != nil
    }
  }
}

#Preview {
  ContentView()
}
