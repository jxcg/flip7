import Foundation

public struct GameEngine: Equatable, Codable, Sendable {
  public private(set) var state: GameState

  public init(
    playerNames: [String],
    deck: Deck,
    dealerIndex: Int = 0
  ) throws {
    try self.init(
      playerNames: playerNames,
      deck: deck,
      dealerIndex: dealerIndex,
      startingScores: Array(repeating: 0, count: playerNames.count)
    )
  }

  public init<R: RandomNumberGenerator>(
    playerNames: [String],
    dealerIndex: Int = 0,
    shufflingWith generator: inout R
  ) throws {
    try self.init(
      playerNames: playerNames,
      deck: Deck.shuffledCanonical(using: &generator),
      dealerIndex: dealerIndex
    )
  }

  init(
    playerNames: [String],
    deck: Deck,
    dealerIndex: Int,
    startingScores: [Int]
  ) throws {
    guard (Ruleset.minimumPlayerCount...Ruleset.maximumPlayerCount).contains(playerNames.count)
    else {
      throw GameRuleError.invalidPlayerCount(playerNames.count)
    }
    guard playerNames.indices.contains(dealerIndex) else {
      throw GameRuleError.invalidDealerIndex(dealerIndex)
    }
    guard startingScores.count == playerNames.count, startingScores.allSatisfy({ $0 >= 0 })
    else {
      throw GameRuleError.invalidStartingScores
    }

    let names = playerNames.enumerated().map { index, name in
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      return (index, trimmed)
    }

    if let emptyName = names.first(where: { $0.1.isEmpty }) {
      throw GameRuleError.emptyPlayerName(index: emptyName.0)
    }

    var normalizedNames = Set<String>()
    for (_, name) in names {
      let normalized = name.lowercased()
      guard normalizedNames.insert(normalized).inserted else {
        throw GameRuleError.duplicatePlayerName(name)
      }
    }

    let players = names.map { index, name in
      PlayerState(
        id: PlayerID(rawValue: index),
        name: name,
        bankedScore: startingScores[index],
        roundCards: RoundCards(),
        status: .active,
        secondChance: nil
      )
    }

    state = GameState(
      players: players,
      deck: deck,
      dealerID: PlayerID(rawValue: dealerIndex),
      roundNumber: 1,
      phase: .waitingToStartRound
    )
  }

  @discardableResult
  public mutating func send(_ command: GameCommand) throws -> [GameEvent] {
    var generator = SystemRandomNumberGenerator()
    return try send(command, using: &generator)
  }

  @discardableResult
  public mutating func send<R: RandomNumberGenerator>(
    _ command: GameCommand,
    using generator: inout R
  ) throws -> [GameEvent] {
    var candidate = self
    var candidateGenerator = generator
    var events: [GameEvent] = []

    try candidate.apply(command, using: &candidateGenerator, events: &events)

    self = candidate
    generator = candidateGenerator
    return events
  }

  private mutating func apply<R: RandomNumberGenerator>(
    _ command: GameCommand,
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    switch command {
    case .startRound:
      guard state.phase == .waitingToStartRound else {
        throw GameRuleError.commandNotAllowed
      }
      try beginRound(using: &generator, events: &events)

    case .startNextRound:
      guard case .roundComplete(let summary) = state.phase else {
        throw GameRuleError.commandNotAllowed
      }
      prepareNextRound(nextDealerID: summary.nextDealerID)
      try beginRound(using: &generator, events: &events)

    case .hit(let playerID):
      let expectedPlayerID = try validateTurn(for: playerID)
      let resolution = try drawCard(
        for: expectedPlayerID,
        continuation: .advanceTurn(after: expectedPlayerID),
        using: &generator,
        events: &events
      )
      if resolution == .resolved {
        advanceTurn(after: expectedPlayerID, events: &events)
      }

    case .stay(let playerID):
      let expectedPlayerID = try validateTurn(for: playerID)
      guard player(at: expectedPlayerID).hasCardInFront else {
        throw GameRuleError.cannotStayWithoutCard(expectedPlayerID)
      }
      updatePlayer(expectedPlayerID) { player in
        player.status = .stayed
      }
      events.append(.playerStayed(expectedPlayerID))
      advanceTurn(after: expectedPlayerID, events: &events)

    case .chooseActionTarget(let cardID, let targetPlayerID):
      guard case .awaitingAction(let decision) = state.phase,
        decision.card.id == cardID,
        decision.legalTargetIDs.contains(targetPlayerID),
        case .action(let action) = decision.card.kind
      else {
        throw GameRuleError.commandNotAllowed
      }

      switch action {
      case .freeze:
        append(decision.card, to: targetPlayerID)
        updatePlayer(targetPlayerID) { player in
          player.status = .frozen
        }
        try continueActionResolution(
          continuation: decision.continuation,
          queuedActions: decision.queuedActions,
          using: &generator,
          events: &events
        )
      case .flipThree:
        try resolveFlipThree(
          decision,
          for: targetPlayerID,
          using: &generator,
          events: &events
        )
      case .secondChance:
        throw GameRuleError.commandNotAllowed
      }
    }
  }

  private mutating func beginRound<R: RandomNumberGenerator>(
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    events.append(
      .roundStarted(
        roundNumber: state.roundNumber,
        dealerID: state.dealerID
      )
    )
    try continueOpeningDeal(from: 0, using: &generator, events: &events)
  }

  private mutating func continueOpeningDeal<R: RandomNumberGenerator>(
    from startingOffset: Int,
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    let order = turnOrder

    for offset in startingOffset..<order.count {
      let playerID = order[offset]
      guard player(at: playerID).status == .active else {
        continue
      }
      state.phase = .dealingOpeningCards(nextOffset: offset)
      let resolution = try drawCard(
        for: playerID,
        continuation: .openingDeal(nextOffset: offset + 1),
        using: &generator,
        events: &events
      )

      if resolution != .resolved {
        return
      }
    }

    guard let firstPlayerID = turnOrder.first(where: { player(at: $0).status == .active })
    else {
      finishRound(reason: .allPlayersInactive, events: &events)
      return
    }
    state.phase = .awaitingTurn(firstPlayerID)
  }

  private mutating func resume<R: RandomNumberGenerator>(
    _ continuation: ActionContinuation,
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    switch continuation {
    case .openingDeal(let nextOffset):
      try continueOpeningDeal(from: nextOffset, using: &generator, events: &events)
    case .advanceTurn(let playerID):
      advanceTurn(after: playerID, events: &events)
    }
  }

  private mutating func resolveFlipThree<R: RandomNumberGenerator>(
    _ decision: PendingActionDecision,
    for playerID: PlayerID,
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    append(decision.card, to: playerID)
    var deferredActions: [DeferredAction] = []

    for _ in 0..<3 {
      let resolution = try drawCard(
        for: playerID,
        continuation: decision.continuation,
        deferringTargetedActions: true,
        using: &generator,
        events: &events
      )
      switch resolution {
      case .resolved:
        break
      case .deferredAction(let card):
        deferredActions.append(
          DeferredAction(sourcePlayerID: playerID, card: card)
        )
      case .roundEnded:
        state.deck.discard(
          contentsOf: (decision.queuedActions + deferredActions).map(\.card)
        )
        return
      case .paused:
        throw GameRuleError.commandNotAllowed
      }
      if player(at: playerID).status != .active {
        state.deck.discard(contentsOf: deferredActions.map(\.card))
        try continueActionResolution(
          continuation: decision.continuation,
          queuedActions: decision.queuedActions,
          using: &generator,
          events: &events
        )
        return
      }
    }

    try continueActionResolution(
      continuation: decision.continuation,
      queuedActions: decision.queuedActions + deferredActions,
      using: &generator,
      events: &events
    )
  }

  private mutating func continueActionResolution<R: RandomNumberGenerator>(
    continuation: ActionContinuation,
    queuedActions: [DeferredAction],
    using generator: inout R,
    events: inout [GameEvent]
  ) throws {
    guard let nextAction = queuedActions.first else {
      try resume(continuation, using: &generator, events: &events)
      return
    }

    let decision = PendingActionDecision(
      sourcePlayerID: nextAction.sourcePlayerID,
      card: nextAction.card,
      legalTargetIDs: state.activePlayerIDs,
      queuedActions: Array(queuedActions.dropFirst()),
      continuation: continuation
    )
    state.phase = .awaitingAction(decision)
    events.append(.actionRequiresResolution(decision))
  }

  private mutating func drawCard<R: RandomNumberGenerator>(
    for playerID: PlayerID,
    continuation: ActionContinuation,
    deferringTargetedActions: Bool = false,
    using generator: inout R,
    events: inout [GameEvent]
  ) throws -> DrawResolution {
    if state.deck.remainingCount == 0 {
      if state.deck.recycleDiscardsIfNeeded(using: &generator) {
        events.append(.deckRecycled)
      }
    }

    guard let card = state.deck.draw() else {
      throw GameRuleError.deckExhausted
    }
    events.append(.cardDrawn(playerID: playerID, card: card))

    switch card.kind {
    case .number(let number):
      return resolveNumber(
        number,
        card: card,
        for: playerID,
        events: &events
      )

    case .scoreModifier:
      append(card, to: playerID)
      return .resolved

    case .action(.secondChance) where player(at: playerID).secondChance == nil:
      updatePlayer(playerID) { player in
        player.secondChance = card
      }
      events.append(.secondChanceGranted(playerID: playerID, card: card))
      return .resolved

    case .action(let action):
      if deferringTargetedActions, action != .secondChance {
        return .deferredAction(card)
      }
      if action == .secondChance,
        !state.players.contains(where: { player in
          player.status == .active && player.secondChance == nil
        })
      {
        state.deck.discard(card)
        return .resolved
      }

      let legalTargetIDs: [PlayerID]
      switch action {
      case .freeze, .flipThree:
        legalTargetIDs = state.activePlayerIDs
      case .secondChance:
        legalTargetIDs = []
      }

      let decision = PendingActionDecision(
        sourcePlayerID: playerID,
        card: card,
        legalTargetIDs: legalTargetIDs,
        queuedActions: [],
        continuation: continuation
      )
      state.phase = .awaitingAction(decision)
      events.append(.actionRequiresResolution(decision))
      return .paused
    }
  }

  private mutating func resolveNumber(
    _ number: NumberValue,
    card: GameCard,
    for playerID: PlayerID,
    events: inout [GameEvent]
  ) -> DrawResolution {
    let existingNumbers = player(at: playerID).roundCards.numberValues

    guard existingNumbers.contains(number) else {
      append(card, to: playerID)
      if player(at: playerID).roundCards.hasFlipSeven {
        events.append(.flipSeven(playerID))
        finishRound(reason: .flipSeven(playerID), events: &events)
        return .roundEnded
      }
      return .resolved
    }

    if let secondChance = player(at: playerID).secondChance {
      updatePlayer(playerID) { player in
        player.secondChance = nil
      }
      state.deck.discard(secondChance)
      state.deck.discard(card)
      events.append(
        .secondChanceUsed(
          playerID: playerID,
          card: secondChance,
          duplicate: card
        )
      )
      return .resolved
    }

    append(card, to: playerID)
    updatePlayer(playerID) { player in
      player.status = .busted
    }
    events.append(.playerBusted(playerID: playerID, duplicate: card))
    return .resolved
  }

  private func validateTurn(for playerID: PlayerID) throws -> PlayerID {
    guard case .awaitingTurn(let expectedPlayerID) = state.phase else {
      throw GameRuleError.commandNotAllowed
    }
    guard playerID == expectedPlayerID else {
      throw GameRuleError.wrongPlayer(expected: expectedPlayerID, actual: playerID)
    }
    return expectedPlayerID
  }

  private mutating func advanceTurn(
    after playerID: PlayerID,
    events: inout [GameEvent]
  ) {
    guard let nextPlayerID = nextActivePlayer(after: playerID) else {
      finishRound(reason: .allPlayersInactive, events: &events)
      return
    }
    state.phase = .awaitingTurn(nextPlayerID)
  }

  private mutating func finishRound(
    reason: RoundEndReason,
    events: inout [GameEvent]
  ) {
    var results: [PlayerRoundResult] = []

    for index in state.players.indices {
      let player = state.players[index]
      let score = player.roundScore
      let newBankedScore = player.bankedScore + score.total

      results.append(
        PlayerRoundResult(
          playerID: player.id,
          status: player.status,
          cards: player.roundCards,
          secondChance: player.secondChance,
          score: score,
          previousBankedScore: player.bankedScore,
          newBankedScore: newBankedScore
        )
      )
      state.players[index].bankedScore = newBankedScore
    }

    let summary = RoundSummary(
      roundNumber: state.roundNumber,
      dealerID: state.dealerID,
      nextDealerID: nextSeat(after: state.dealerID),
      reason: reason,
      playerResults: results
    )
    events.append(.roundEnded(summary))

    let winningScore = state.players.map(\.bankedScore).max() ?? 0
    if winningScore >= Ruleset.targetScore {
      let winnerIDs = state.players.filter { $0.bankedScore == winningScore }.map(\.id)
      let result = GameResult(
        finalRound: summary,
        winnerIDs: winnerIDs,
        winningScore: winningScore
      )
      state.phase = .gameComplete(result)
      events.append(.gameEnded(result))
    } else {
      state.phase = .roundComplete(summary)
    }
  }

  private mutating func prepareNextRound(nextDealerID: PlayerID) {
    for index in state.players.indices {
      state.deck.discard(contentsOf: state.players[index].roundCards.cards)
      if let secondChance = state.players[index].secondChance {
        state.deck.discard(secondChance)
      }
      state.players[index].roundCards = RoundCards()
      state.players[index].status = .active
      state.players[index].secondChance = nil
    }

    state.dealerID = nextDealerID
    state.roundNumber += 1
    state.phase = .waitingToStartRound
  }

  private var turnOrder: [PlayerID] {
    let dealerIndex = playerIndex(for: state.dealerID)
    return (1...state.players.count).map { distance in
      state.players[(dealerIndex + distance) % state.players.count].id
    }
  }

  private func nextSeat(after playerID: PlayerID) -> PlayerID {
    let index = playerIndex(for: playerID)
    return state.players[(index + 1) % state.players.count].id
  }

  private func nextActivePlayer(after playerID: PlayerID) -> PlayerID? {
    let index = playerIndex(for: playerID)

    for distance in 1...state.players.count {
      let candidate = state.players[(index + distance) % state.players.count]
      if candidate.status == .active {
        return candidate.id
      }
    }
    return nil
  }

  private func playerIndex(for playerID: PlayerID) -> Int {
    precondition(
      state.players.indices.contains(playerID.rawValue),
      "Player IDs must remain aligned with seat indices"
    )
    return playerID.rawValue
  }

  private func player(at playerID: PlayerID) -> PlayerState {
    state.players[playerIndex(for: playerID)]
  }

  private mutating func updatePlayer(
    _ playerID: PlayerID,
    update: (inout PlayerState) -> Void
  ) {
    update(&state.players[playerIndex(for: playerID)])
  }

  private mutating func append(_ card: GameCard, to playerID: PlayerID) {
    updatePlayer(playerID) { player in
      player.roundCards = player.roundCards.appending(card)
    }
  }
}

private enum DrawResolution: Equatable {
  case resolved
  case paused
  case roundEnded
  case deferredAction(GameCard)
}
