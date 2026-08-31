import SwiftUI

#if SWIFT_PACKAGE
  import Flip7Core
#endif

struct GameTableView: View {
  let session: GameSession
  @AccessibilityFocusState private var isCommandErrorFocused: Bool
  /// Card height plus breathing room. Tracks the numeral so the row grows with
  /// Dynamic Type instead of clipping.
  @ScaledMetric(relativeTo: .largeTitle) private var handHeight: Double = 104

  var body: some View {
    if let state = session.state {
      VStack(spacing: 0) {
        // The active player owns the top of the screen; opponents compress to
        // one row each and sit just above the thumb zone.
        ScrollView {
          activeHand(state)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)

        Spacer(minLength: 12)

        opponents(state)
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

        actionBar(state)
      }
      .background(TablePalette.table)
      .navigationTitle("Round \(state.roundNumber)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { chrome(state) }
      .onChange(of: session.commandError) { _, error in
        isCommandErrorFocused = error != nil
      }
    } else {
      ContentUnavailableView(
        "No game",
        systemImage: "rectangle.on.rectangle.slash",
        description: Text("Start a new game to play.")
      )
    }
  }

  // MARK: Chrome

  @ToolbarContentBuilder
  private func chrome(_ state: GameState) -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      // Set as machine output: a readout that changes.
      // A readout that changes, set as machine output.
      Label("\(state.deck.remainingCount)", systemImage: "rectangle.stack")
        .font(.footnote.monospaced())
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
        .accessibilityLabel("\(state.deck.remainingCount) cards left in the deck")
    }
  }

  // MARK: The player

  @ViewBuilder
  private func activeHand(_ state: GameState) -> some View {
    if let you = state.players.first(where: { $0.id == session.humanPlayerID }) {
      VStack(alignment: .leading, spacing: 12) {
        hand(for: you)
        RailView(held: Set(you.roundCards.numberValues))
        HStack(alignment: .firstTextBaseline) {
          Text(you.name)
            .font(.body.weight(.semibold))
          if you.status != .active {
            Text(you.status.displayName)
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(Capsule().fill(Color(.tertiarySystemFill)))
          }
          Spacer()
          Text("\(you.bankedScore + you.roundScore.total)")
            .font(.body.monospacedDigit().weight(.semibold))
            .accessibilityLabel(
              "\(you.bankedScore) banked, \(you.roundScore.total) this round")
        }
      }
    }
  }

  @ViewBuilder
  private func hand(for player: PlayerState) -> some View {
    let cards = player.roundCards.cards + [player.secondChance].compactMap { $0 }
    if cards.isEmpty {
      Text("No cards yet")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(height: handHeight, alignment: .leading)
    } else {
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 8) {
          ForEach(cards) { card in
            CardView(card: card, isDrained: player.status == .busted)
          }
        }
        .padding(.vertical, 4)
      }
      .frame(height: handHeight)
    }
  }

  // MARK: Opponents

  private func opponents(_ state: GameState) -> some View {
    VStack(spacing: 0) {
      ForEach(state.players.filter { $0.id != session.humanPlayerID }) { player in
        opponentRow(player, isActing: player.id == session.actingPlayerID)
        if player.id != state.players.last?.id {
          Divider().overlay(Color(.separator))
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(TablePalette.surface)
    )
  }

  /// Opponents compress to one row each so nine players still fit. The one
  /// currently acting expands to real cards: in solo play you watch every
  /// opponent turn, and a single dot appearing is a thin thing to wait for.
  private func opponentRow(_ player: PlayerState, isActing: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Text(player.name)
          .font(.subheadline.weight(isActing ? .semibold : .regular))
          .lineLimit(1)
        if !isActing {
          hueDots(for: player)
        }
        Spacer(minLength: 8)
        if player.status != .active {
          Text(player.status.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        Text("\(player.bankedScore + player.roundScore.total)")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      if isActing {
        hand(for: player)
      }
    }
    .padding(.vertical, 10)
    .accessibilityElement(children: .combine)
  }

  private func hueDots(for player: PlayerState) -> some View {
    HStack(spacing: 3) {
      ForEach(player.roundCards.cards) { card in
        Circle()
          .fill(dotColor(for: card, isBusted: player.status == .busted))
          .frame(width: 8, height: 8)
      }
    }
    .accessibilityHidden(true)
  }

  private func dotColor(for card: GameCard, isBusted: Bool) -> Color {
    guard !isBusted else {
      return Color(.label).opacity(0.2)
    }
    if case .number(let value) = card.kind {
      return CardPalette.rail(for: value.rawValue)
    }
    return Color(.label).opacity(0.45)
  }

  // MARK: The action bar

  @ViewBuilder
  private func actionBar(_ state: GameState) -> some View {
    VStack(spacing: 10) {
      if let message = session.turnOutcome?.messages.last {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .lineLimit(2)
      }
      if let commandError = session.commandError {
        Text(commandError)
          .font(.footnote)
          .foregroundStyle(Color(.systemRed))
          .accessibilityFocused($isCommandErrorFocused)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      controls(state)
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(.regularMaterial)
  }

  @ViewBuilder
  private func controls(_ state: GameState) -> some View {
    switch state.phase {
    case .awaitingTurn(let playerID) where session.isHumanTurn:
      turnControls(playerID: playerID, state: state)
    case .awaitingAction(let decision) where session.isHumanTurn:
      targetControls(decision: decision, state: state)
    case .awaitingTurn, .awaitingAction:
      waiting()
    case .roundComplete(let summary):
      roundSummary(summary, state: state)
    case .gameComplete(let result):
      gameResult(result, state: state)
    case .waitingToStartRound, .dealingOpeningCards:
      waiting()
    }
  }

  private func waiting() -> some View {
    Text(session.actingPlayerName.map { "\($0) is deciding" } ?? "Dealing")
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
      .accessibilityLabel(session.turnPrompt ?? "Waiting")
  }

  private func turnControls(playerID: PlayerID, state: GameState) -> some View {
    let inputVersion = session.inputVersion
    let canStay = state.players.first { $0.id == playerID }?.hasCardInFront == true
    return HStack(spacing: 12) {
      Button("Stay") { session.stay(playerID, inputVersion: inputVersion) }
        .buttonStyle(.bordered)
        .disabled(!canStay)
      Button("Hit") { session.hit(playerID, inputVersion: inputVersion) }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }
    .controlSize(.large)
    .frame(minHeight: 50)
  }

  private func targetControls(
    decision: PendingActionDecision,
    state: GameState
  ) -> some View {
    let inputVersion = session.inputVersion
    return VStack(alignment: .leading, spacing: 8) {
      Text("Give \(decision.card.displayName) to")
        .font(.footnote.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(decision.legalTargetIDs, id: \.self) { playerID in
            Button(state.playerName(for: playerID)) {
              session.chooseActionTarget(
                cardID: decision.card.id,
                targetPlayerID: playerID,
                inputVersion: inputVersion
              )
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(
              "Give \(decision.card.displayName) to \(state.playerName(for: playerID))")
          }
        }
      }
    }
    .controlSize(.large)
    .frame(minHeight: 50)
  }

  private func roundSummary(_ summary: RoundSummary, state: GameState) -> some View {
    let inputVersion = session.inputVersion
    return Button("Start round \(summary.roundNumber + 1)") {
      session.startNextRound(inputVersion: inputVersion)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .frame(maxWidth: .infinity, minHeight: 50)
  }

  private func gameResult(_ result: GameResult, state: GameState) -> some View {
    let winners = result.winnerIDs.map { state.playerName(for: $0) }
      .joined(separator: ", ")
    return Text("\(winners) won with \(result.winningScore)")
      .font(.headline)
      .frame(maxWidth: .infinity, minHeight: 50)
  }
}
