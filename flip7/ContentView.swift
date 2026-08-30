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
                PlayerHandoffView(session: session)
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
                        .onChange(of: player.name) { _, _ in
                            session.clearSetupError()
                        }
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
        ScrollView {
            Group {
                if let playerName = session.actingPlayerName {
                    if session.isActingPlayerRevealed {
                        GameReadyView(
                            playerName: playerName,
                            hide: session.hidePlayerView
                        )
                    } else {
                        VStack(spacing: 16) {
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
                        }
                    }
                } else {
                    Text("The game couldn't identify the next player.")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Pass the Device")
    }
}

private struct GameReadyView: View {
    let playerName: String
    let hide: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("\(playerName)'s turn")
                .font(.title)
            Text("The game session is ready.")
            Button("Hide", action: hide)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Game")
    }
}

#Preview {
    ContentView()
}
