import Testing

@testable import Flip7Core

@Test("An empty round has a zero score")
func emptyRoundScore() {
  let score = RoundCards().score()

  #expect(score.numberSubtotal == 0)
  #expect(score.multiplier == 1)
  #expect(score.additiveBonus == 0)
  #expect(score.flipSevenBonus == 0)
  #expect(score.total == 0)
}

@Test("The multiplier applies before additive modifiers")
func modifierOrder() {
  let cards = RoundCards(cards: [
    testCard(1, .number(.ten)),
    testCard(2, .number(.four)),
    testCard(3, .scoreModifier(.double)),
    testCard(4, .scoreModifier(.additive(.two))),
    testCard(5, .scoreModifier(.additive(.ten))),
    testCard(6, .action(.freeze)),
  ])
  let score = cards.score()

  #expect(score.numberSubtotal == 14)
  #expect(score.multiplier == 2)
  #expect(score.additiveBonus == 12)
  #expect(score.flipSevenBonus == 0)
  #expect(score.total == 40)
}

@Test("Seven unique number cards earn the bonus")
func flipSevenBonus() {
  let cards = RoundCards(cards: [
    testCard(10, .number(.zero)),
    testCard(11, .number(.one)),
    testCard(12, .number(.two)),
    testCard(13, .number(.three)),
    testCard(14, .number(.four)),
    testCard(15, .number(.five)),
    testCard(16, .number(.six)),
  ])
  let score = cards.score()

  #expect(cards.uniqueNumberCount == 7)
  #expect(cards.hasFlipSeven)
  #expect(score.numberSubtotal == 21)
  #expect(score.flipSevenBonus == 15)
  #expect(score.total == 36)
}

@Test("Duplicate values do not count twice toward Flip Seven")
func duplicateNumbersAreNotUnique() {
  let cards = RoundCards(cards: [
    testCard(20, .number(.one)),
    testCard(21, .number(.one)),
    testCard(22, .number(.two)),
    testCard(23, .number(.three)),
    testCard(24, .number(.four)),
    testCard(25, .number(.five)),
    testCard(26, .number(.six)),
  ])

  #expect(cards.numberCards.count == 7)
  #expect(cards.uniqueNumberCount == 6)
  #expect(cards.hasFlipSeven == false)
  #expect(cards.score().flipSevenBonus == 0)
}

@Test("A busted round scores zero while retaining its breakdown")
func bustScore() {
  let cards = RoundCards(cards: [
    testCard(30, .number(.twelve)),
    testCard(31, .scoreModifier(.double)),
    testCard(32, .scoreModifier(.additive(.ten))),
  ])
  let score = cards.score(isBusted: true)

  #expect(score.numberSubtotal == 12)
  #expect(score.eligibleTotal == 34)
  #expect(score.isBusted)
  #expect(score.total == 0)
}

@Test("Banked score and round cards are represented independently")
func scoringStateSeparation() {
  let roundCards = RoundCards(cards: [testCard(40, .number(.eight))])
  let state = PlayerScoringState(bankedScore: 73, roundCards: roundCards)

  #expect(state.bankedScore == 73)
  #expect(state.roundCards.score().total == 8)
}

private func testCard(_ id: Int, _ kind: CardKind) -> GameCard {
  GameCard(id: CardID(rawValue: id), kind: kind)
}
