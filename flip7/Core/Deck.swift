public struct Deck: Equatable, Codable, Sendable {
  public private(set) var drawPile: [GameCard]
  public private(set) var discardPile: [GameCard]

  public init(
    drawPile: [GameCard],
    discardPile: [GameCard] = []
  ) {
    self.drawPile = drawPile
    self.discardPile = discardPile
  }

  public static var canonical: Deck {
    Deck(drawPile: Ruleset.canonicalCards)
  }

  public static func shuffledCanonical<R: RandomNumberGenerator>(
    using generator: inout R
  ) -> Deck {
    var cards = Ruleset.canonicalCards
    cards.shuffle(using: &generator)
    return Deck(drawPile: cards)
  }

  public var remainingCount: Int {
    drawPile.count
  }

  public var discardedCount: Int {
    discardPile.count
  }

  public var nextCard: GameCard? {
    drawPile.first
  }

  @discardableResult
  public mutating func draw() -> GameCard? {
    guard !drawPile.isEmpty else {
      return nil
    }

    return drawPile.removeFirst()
  }

  public mutating func discard(_ card: GameCard) {
    discardPile.append(card)
  }

  public mutating func discard(contentsOf cards: some Sequence<GameCard>) {
    discardPile.append(contentsOf: cards)
  }

  @discardableResult
  public mutating func recycleDiscardsIfNeeded<R: RandomNumberGenerator>(
    using generator: inout R
  ) -> Bool {
    guard drawPile.isEmpty, !discardPile.isEmpty else {
      return false
    }

    drawPile = discardPile
    discardPile.removeAll(keepingCapacity: true)
    drawPile.shuffle(using: &generator)
    return true
  }
}
