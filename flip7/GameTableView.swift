import SwiftUI

struct GameTableView: View {
  let session: GameSession
  @AccessibilityFocusState private var isCommandErrorFocused: Bool

  var body: some View {
    if let state = session.state {
      Form {
        if session.needsHandoff, let playerName = session.presentedPlayerName {
          handoff(playerName)
        }

        gameStatus(state)

        Group {
          if let outcome = session.turnOutcome {
            outcomeSection(outcome)
          } else {
            controls(for: state)
          }
        }
        .disabled(session.needsHandoff)

        players(state)

        if let commandError = session.commandError {
          Section("Action Error") {
            Text(commandError)
              .foregroundStyle(.red)
              .accessibilityFocused($isCommandErrorFocused)
          }
        }
      }
      .onChange(of: session.commandError) { _, error in
        isCommandErrorFocused = error != nil
      }
    } else {
      Text("The game isn't available.")
    }
  }

  private func handoff(_ playerName: String) -> some View {
    Section("Pass the Device") {
      Text("\(playerName)'s turn")
      Text("Confirm the next player before using the game controls.")
      Button("I'm \(playerName)") {
        session.revealForCurrentPlayer()
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
  }

  private func gameStatus(_ state: GameState) -> some View {
    Section("Game") {
      LabeledContent("Round", value: "\(state.roundNumber)")
      LabeledContent("Dealer", value: state.playerName(for: state.dealerID))
      LabeledContent(
        "Deck",
        value: "\(state.deck.remainingCount) remaining, "
          + "\(state.deck.discardedCount) discarded"
      )
      if let actingPlayerName = session.actingPlayerName {
        LabeledContent("Decision maker", value: actingPlayerName)
      }
    }
  }

  private func outcomeSection(_ outcome: GameSession.TurnOutcome) -> some View {
    Section("Latest Result") {
      ForEach(Array(outcome.messages.enumerated()), id: \.offset) { _, message in
        Text(message)
      }

      Button("Continue") {
        session.continueAfterOutcome()
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
  }

  @ViewBuilder
  private func controls(for state: GameState) -> some View {
    switch state.phase {
    case .waitingToStartRound:
      Section("Round") {
        Text("Ready to deal.")
      }
    case .dealingOpeningCards:
      Section("Round") {
        Text("Dealing opening cards.")
      }
    case .awaitingTurn(let playerID):
      turnControls(playerID: playerID, state: state)
    case .awaitingAction(let decision):
      targetControls(decision: decision, state: state)
    case .roundComplete(let summary):
      roundSummary(summary, state: state)
    case .gameComplete(let result):
      gameResult(result, state: state)
    }
  }

  private func turnControls(playerID: PlayerID, state: GameState) -> some View {
    let inputVersion = session.inputVersion
    let canStay = state.players.first { $0.id == playerID }?.hasCardInFront == true
    return Section("Available Actions") {
      Button("Hit") {
        session.hit(playerID, inputVersion: inputVersion)
      }
      .frame(maxWidth: .infinity, minHeight: 44)

      Button("Stay") {
        session.stay(playerID, inputVersion: inputVersion)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .disabled(!canStay)
    }
  }

  private func targetControls(
    decision: PendingActionDecision,
    state: GameState
  ) -> some View {
    let inputVersion = session.inputVersion
    return Section("Choose \(decision.card.displayName) Target") {
      ForEach(decision.legalTargetIDs, id: \.self) { playerID in
        Button(state.playerName(for: playerID)) {
          session.chooseActionTarget(
            cardID: decision.card.id,
            targetPlayerID: playerID,
            inputVersion: inputVersion
          )
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityLabel(
          "Give \(decision.card.displayName) to \(state.playerName(for: playerID))"
        )
      }
    }
  }

  private func roundSummary(
    _ summary: RoundSummary,
    state: GameState
  ) -> some View {
    let inputVersion = session.inputVersion
    return Section("Round \(summary.roundNumber) Result") {
      Text(roundEndText(summary.reason, state: state))

      ForEach(summary.playerResults, id: \.playerID) { result in
        LabeledContent(
          state.playerName(for: result.playerID),
          value: "\(result.score.total) this round, "
            + "\(result.newBankedScore) total"
        )
      }

      Button("Start Next Round") {
        session.startNextRound(inputVersion: inputVersion)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
  }

  private func gameResult(_ result: GameResult, state: GameState) -> some View {
    let winners = result.winnerIDs.map { state.playerName(for: $0) }.joined(separator: ", ")
    return Section("Final Result") {
      Text("\(winners) won with \(result.winningScore) points.")
    }
  }

  private func players(_ state: GameState) -> some View {
    Section("Players") {
      ForEach(state.players) { player in
        PlayerTableRow(
          player: player,
          isDealer: player.id == state.dealerID,
          isDecisionMaker: player.id == session.actingPlayerID
        )
      }
    }
  }

  private func roundEndText(_ reason: RoundEndReason, state: GameState) -> String {
    switch reason {
    case .allPlayersInactive:
      "No active players remain."
    case .flipSeven(let playerID):
      "\(state.playerName(for: playerID)) revealed seven different number cards."
    }
  }
}

private struct PlayerTableRow: View {
  let player: PlayerState
  let isDealer: Bool
  let isDecisionMaker: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(player.name)
        .font(.headline)

      if isDealer {
        Label("Dealer", systemImage: "person.circle")
      }
      if isDecisionMaker {
        Label("Decision maker", systemImage: "arrow.right.circle")
      }

      Label(player.status.displayName, systemImage: player.status.systemImage)
      Text("Total score: \(player.bankedScore)")
      Text("Round score: \(player.roundScore.total)")

      if player.roundCards.cards.isEmpty, player.secondChance == nil {
        Text("No cards")
      } else {
        ForEach(player.roundCards.cards) { card in
          Label(card.displayName, systemImage: card.systemImage)
        }
        if let secondChance = player.secondChance {
          Label(secondChance.displayName, systemImage: secondChance.systemImage)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }
}
