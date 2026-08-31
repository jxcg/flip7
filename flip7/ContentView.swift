import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var session = GameSession()
  @State private var isShowingSession = false

  var body: some View {
    Group {
      if scenePhase == .active {
        NavigationStack {
          NewGameView(session: session) {
            if session.start() {
              isShowingSession = true
            }
          }
          .navigationDestination(isPresented: $isShowingSession) {
            PlayerHandoffView(session: session)
          }
          .onChange(of: isShowingSession) { _, isShowing in
            if !isShowing {
              session.resetGame()
            }
          }
        }
      } else {
        Text("Game Hidden")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        session.conceal()
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
        ForEach(Array($session.playerDrafts.enumerated()), id: \.element.id) {
          index, $player in
          TextField("Player name", text: $player.name)
            .textContentType(.name)
            .accessibilityLabel("Player \(index + 1) name")
            .deleteDisabled(!session.canRemovePlayer)
        }
        .onDelete { session.removePlayers(at: $0) }
        .onMove { session.movePlayers(from: $0, to: $1) }

        if let setupError = session.setupError {
          Text(setupError)
            .foregroundStyle(.red)
            .accessibilityLabel("Setup error: \(setupError)")
            .accessibilityFocused($isSetupErrorFocused)
        }

        Button(action: session.addPlayer) {
          Label("Add Player", systemImage: "plus")
        }
        .disabled(!session.canAddPlayer)

        EditButton()
      } header: {
        Text("Players")
      } footer: {
        Text(
          "Add \(Ruleset.minimumPlayerCount) to "
            + "\(Ruleset.maximumPlayerCount) players."
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

private struct PlayerHandoffView: View {
  let session: GameSession

  var body: some View {
    Group {
      if session.needsHandoff {
        ScrollView {
          VStack(spacing: 16) {
            if let playerName = session.presentedPlayerName {
              Text("Pass the device to \(playerName)")
                .font(.title)
                .multilineTextAlignment(.center)

              Text("Continue only when nobody else can see the screen.")
                .multilineTextAlignment(.center)

              Button("I'm \(playerName)") {
                session.revealForCurrentPlayer()
              }
              .buttonStyle(.borderedProminent)
              .frame(minHeight: 44)
            } else {
              Text("The game couldn't identify the next player.")
            }
          }
          .frame(maxWidth: .infinity)
          .padding()
        }
      } else {
        GameTableView(session: session)
      }
    }
    .navigationTitle(session.needsHandoff ? "Pass the Device" : "Game")
  }
}

#Preview {
  ContentView()
}
