public enum Ruleset {
  public static let minimumPlayerCount = 3
  public static let maximumPlayerCount = 9
  public static let targetScore = 200
  public static let flipSevenNumberCount = 7
  public static let flipSevenBonus = 15

  public static let canonicalCards: [GameCard] = {
    var kinds = [CardKind.number(.zero)]

    for number in NumberValue.allCases.dropFirst() {
      kinds.append(
        contentsOf: repeatElement(
          CardKind.number(number),
          count: number.rawValue
        )
      )
    }

    kinds.append(
      contentsOf: AdditiveModifier.allCases.map {
        CardKind.scoreModifier(.additive($0))
      }
    )
    kinds.append(.scoreModifier(.double))

    for action in ActionCard.allCases {
      kinds.append(
        contentsOf: repeatElement(
          CardKind.action(action),
          count: 3
        )
      )
    }

    return kinds.enumerated().map { offset, kind in
      GameCard(id: CardID(rawValue: offset), kind: kind)
    }
  }()
}
