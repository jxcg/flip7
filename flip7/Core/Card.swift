public struct CardID: RawRepresentable, Hashable, Codable, Sendable, Comparable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static func < (lhs: CardID, rhs: CardID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public enum NumberValue: Int, CaseIterable, Codable, Sendable {
  case zero = 0
  case one = 1
  case two = 2
  case three = 3
  case four = 4
  case five = 5
  case six = 6
  case seven = 7
  case eight = 8
  case nine = 9
  case ten = 10
  case eleven = 11
  case twelve = 12
}

public enum AdditiveModifier: Int, CaseIterable, Codable, Sendable {
  case two = 2
  case four = 4
  case six = 6
  case eight = 8
  case ten = 10
}

public enum ScoreModifier: Hashable, Codable, Sendable {
  case additive(AdditiveModifier)
  case double
}

public enum ActionCard: String, CaseIterable, Codable, Sendable {
  case freeze
  case flipThree
  case secondChance
}

public enum CardKind: Hashable, Codable, Sendable {
  case number(NumberValue)
  case scoreModifier(ScoreModifier)
  case action(ActionCard)
}

public struct GameCard: Identifiable, Hashable, Codable, Sendable {
  public let id: CardID
  public let kind: CardKind

  public init(id: CardID, kind: CardKind) {
    self.id = id
    self.kind = kind
  }
}
