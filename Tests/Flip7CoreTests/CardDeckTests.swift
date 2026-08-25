import Testing

@testable import Flip7Core

@Test("The canonical deck contains the exact 94-card ruleset")
func canonicalDeckComposition() {
  let cards = Ruleset.canonicalCards

  let numberCards = cards.filter {
    if case .number = $0.kind { true } else { false }
  }
  let modifiers = cards.filter {
    if case .scoreModifier = $0.kind { true } else { false }
  }
  let actions = cards.filter {
    if case .action = $0.kind { true } else { false }
  }

  #expect(cards.count == 94)
  #expect(numberCards.count == 79)
  #expect(modifiers.count == 6)
  #expect(actions.count == 9)
  #expect(Set(cards.map(\.id)).count == cards.count)

  for number in NumberValue.allCases {
    let expectedCount = number == .zero ? 1 : number.rawValue
    let actualCount = cards.count {
      $0.kind == .number(number)
    }
    #expect(actualCount == expectedCount)
  }

  for modifier in AdditiveModifier.allCases {
    #expect(cards.count { $0.kind == .scoreModifier(.additive(modifier)) } == 1)
  }
  #expect(cards.count { $0.kind == .scoreModifier(.double) } == 1)

  for action in ActionCard.allCases {
    #expect(cards.count { $0.kind == .action(action) } == 3)
  }
}

@Test("Injected draw order is consumed from the front")
func injectedDrawOrder() {
  let first = testCard(100, .number(.one))
  let second = testCard(101, .action(.freeze))
  var deck = Deck(drawPile: [first, second])

  #expect(deck.nextCard == first)
  #expect(deck.draw() == first)
  #expect(deck.draw() == second)
  #expect(deck.draw() == nil)
  #expect(deck.remainingCount == 0)
}

@Test("Canonical shuffling is injectable and reproducible")
func deterministicShuffle() {
  var firstGenerator = SeededGenerator(seed: 42)
  var secondGenerator = SeededGenerator(seed: 42)

  let firstDeck = Deck.shuffledCanonical(using: &firstGenerator)
  let secondDeck = Deck.shuffledCanonical(using: &secondGenerator)

  #expect(firstDeck == secondDeck)
  #expect(firstDeck.drawPile != Ruleset.canonicalCards)
  #expect(Set(firstDeck.drawPile.map(\.id)) == Set(Ruleset.canonicalCards.map(\.id)))
}

@Test("Discards recycle only after the draw pile is exhausted")
func discardRecycling() {
  let first = testCard(200, .number(.two))
  let second = testCard(201, .number(.three))
  var generator = SeededGenerator(seed: 7)
  var deck = Deck(drawPile: [first, second])

  deck.discard(testCard(202, .scoreModifier(.double)))
  let recycledEarly = deck.recycleDiscardsIfNeeded(using: &generator)
  #expect(recycledEarly == false)

  #expect(deck.draw() == first)
  #expect(deck.draw() == second)
  let recycledAfterExhaustion = deck.recycleDiscardsIfNeeded(using: &generator)
  #expect(recycledAfterExhaustion)
  #expect(deck.remainingCount == 1)
  #expect(deck.discardedCount == 0)
}

private func testCard(_ id: Int, _ kind: CardKind) -> GameCard {
  GameCard(id: CardID(rawValue: id), kind: kind)
}

private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return state
  }
}
