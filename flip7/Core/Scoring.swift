public struct RoundCards: Equatable, Codable, Sendable {
  public let cards: [GameCard]

  public init(cards: [GameCard] = []) {
    self.cards = cards
  }

  public var numberCards: [GameCard] {
    cards.filter {
      if case .number = $0.kind {
        true
      } else {
        false
      }
    }
  }

  public var numberValues: [NumberValue] {
    cards.compactMap {
      if case .number(let value) = $0.kind {
        value
      } else {
        nil
      }
    }
  }

  public var scoreModifiers: [ScoreModifier] {
    cards.compactMap {
      if case .scoreModifier(let modifier) = $0.kind {
        modifier
      } else {
        nil
      }
    }
  }

  public var actionCards: [ActionCard] {
    cards.compactMap {
      if case .action(let action) = $0.kind {
        action
      } else {
        nil
      }
    }
  }

  public var uniqueNumberCount: Int {
    Set(numberValues).count
  }

  public var hasFlipSeven: Bool {
    uniqueNumberCount >= Ruleset.flipSevenNumberCount
  }

  public func appending(_ card: GameCard) -> RoundCards {
    RoundCards(cards: cards + [card])
  }

  public func score(isBusted: Bool = false) -> ScoreBreakdown {
    ScoreBreakdown(cards: self, isBusted: isBusted)
  }
}

public struct ScoreBreakdown: Equatable, Codable, Sendable {
  public let numberSubtotal: Int
  public let multiplier: Int
  public let additiveBonus: Int
  public let flipSevenBonus: Int
  public let isBusted: Bool

  public init(cards: RoundCards, isBusted: Bool = false) {
    numberSubtotal = cards.numberValues.reduce(0) { $0 + $1.rawValue }
    multiplier = cards.scoreModifiers.contains(.double) ? 2 : 1
    additiveBonus = cards.scoreModifiers.reduce(into: 0) { total, modifier in
      if case .additive(let value) = modifier {
        total += value.rawValue
      }
    }
    flipSevenBonus = cards.hasFlipSeven ? Ruleset.flipSevenBonus : 0
    self.isBusted = isBusted
  }

  public var eligibleTotal: Int {
    (numberSubtotal * multiplier) + additiveBonus + flipSevenBonus
  }

  public var total: Int {
    isBusted ? 0 : eligibleTotal
  }
}

public struct PlayerScoringState: Equatable, Codable, Sendable {
  public let bankedScore: Int
  public let roundCards: RoundCards

  public init(
    bankedScore: Int = 0,
    roundCards: RoundCards = RoundCards()
  ) {
    precondition(bankedScore >= 0, "A banked score cannot be negative")
    self.bankedScore = bankedScore
    self.roundCards = roundCards
  }
}
