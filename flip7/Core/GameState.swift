import Foundation

public struct PlayerID: RawRepresentable, Hashable, Codable, Sendable, Comparable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static func < (lhs: PlayerID, rhs: PlayerID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public enum PlayerRoundStatus: String, Codable, Sendable {
  case active
  case stayed
  case busted
  case frozen
}

public struct PlayerState: Identifiable, Equatable, Codable, Sendable {
  public let id: PlayerID
  public let name: String
  public internal(set) var bankedScore: Int
  public internal(set) var roundCards: RoundCards
  public internal(set) var status: PlayerRoundStatus
  public internal(set) var secondChance: GameCard?

  public var hasCardInFront: Bool {
    !roundCards.cards.isEmpty || secondChance != nil
  }

  public var roundScore: ScoreBreakdown {
    roundCards.score(isBusted: status == .busted)
  }
}

public enum RoundEndReason: Equatable, Codable, Sendable {
  case allPlayersInactive
  case flipSeven(PlayerID)
}

public struct PlayerRoundResult: Equatable, Codable, Sendable {
  public let playerID: PlayerID
  public let status: PlayerRoundStatus
  public let cards: RoundCards
  public let secondChance: GameCard?
  public let score: ScoreBreakdown
  public let previousBankedScore: Int
  public let newBankedScore: Int
}

public struct RoundSummary: Equatable, Codable, Sendable {
  public let roundNumber: Int
  public let dealerID: PlayerID
  public let nextDealerID: PlayerID
  public let reason: RoundEndReason
  public let playerResults: [PlayerRoundResult]
}

public struct GameResult: Equatable, Codable, Sendable {
  public let finalRound: RoundSummary
  public let winnerIDs: [PlayerID]
  public let winningScore: Int
}

public enum ActionContinuation: Equatable, Codable, Sendable {
  case openingDeal(nextOffset: Int)
  case advanceTurn(after: PlayerID)
}

struct DeferredAction: Equatable, Codable, Sendable {
  let sourcePlayerID: PlayerID
  let card: GameCard
}

struct ForcedDrawProgress: Equatable, Codable, Sendable {
  let playerID: PlayerID
  let remainingDrawCount: Int
  let deferredActions: [DeferredAction]
}

public struct PendingActionDecision: Equatable, Codable, Sendable {
  public let sourcePlayerID: PlayerID
  public let card: GameCard
  public let legalTargetIDs: [PlayerID]
  let queuedActions: [DeferredAction]
  let forcedDraw: ForcedDrawProgress?
  public let continuation: ActionContinuation
}

public enum GamePhase: Equatable, Codable, Sendable {
  case waitingToStartRound
  case dealingOpeningCards(nextOffset: Int)
  case awaitingTurn(PlayerID)
  case awaitingAction(PendingActionDecision)
  case roundComplete(RoundSummary)
  case gameComplete(GameResult)
}

public struct GameState: Equatable, Codable, Sendable {
  public internal(set) var players: [PlayerState]
  public internal(set) var deck: Deck
  public internal(set) var dealerID: PlayerID
  public internal(set) var roundNumber: Int
  public internal(set) var phase: GamePhase

  public var currentPlayerID: PlayerID? {
    if case .awaitingTurn(let playerID) = phase {
      playerID
    } else {
      nil
    }
  }

  public var activePlayerIDs: [PlayerID] {
    players.filter { $0.status == .active }.map(\.id)
  }
}

public enum GameCommand: Equatable, Codable, Sendable {
  case startRound
  case hit(PlayerID)
  case stay(PlayerID)
  case startNextRound
  case chooseActionTarget(cardID: CardID, targetPlayerID: PlayerID)
}

public enum GameEvent: Equatable, Codable, Sendable {
  case roundStarted(roundNumber: Int, dealerID: PlayerID)
  case deckRecycled
  case cardDrawn(playerID: PlayerID, card: GameCard)
  case secondChanceGranted(playerID: PlayerID, card: GameCard)
  case secondChanceUsed(playerID: PlayerID, card: GameCard, duplicate: GameCard)
  case playerStayed(PlayerID)
  case playerBusted(playerID: PlayerID, duplicate: GameCard)
  case flipSeven(PlayerID)
  case actionRequiresResolution(PendingActionDecision)
  case roundEnded(RoundSummary)
  case gameEnded(GameResult)
}

public enum GameRuleError: Error, Equatable, Sendable {
  case invalidPlayerCount(Int)
  case emptyPlayerName(index: Int)
  case duplicatePlayerName(String)
  case invalidDealerIndex(Int)
  case invalidStartingScores
  case commandNotAllowed
  case wrongPlayer(expected: PlayerID, actual: PlayerID)
  case cannotStayWithoutCard(PlayerID)
  case deckExhausted
}
