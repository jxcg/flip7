#if SWIFT_PACKAGE
  import Flip7Core
#endif

extension GameState {
  func playerName(for playerID: PlayerID) -> String {
    players.first { $0.id == playerID }?.name ?? "Player \(playerID.rawValue + 1)"
  }
}

extension GameCard {
  var displayName: String {
    switch kind {
    case .number(let value):
      "Number \(value.rawValue)"
    case .scoreModifier(.additive(let modifier)):
      "Plus \(modifier.rawValue)"
    case .scoreModifier(.double):
      "Double score"
    case .action(.freeze):
      "Freeze"
    case .action(.flipThree):
      "Flip Three"
    case .action(.secondChance):
      "Second Chance"
    }
  }

  var systemImage: String {
    switch kind {
    case .number:
      "number.square"
    case .scoreModifier(.additive):
      "plus.square"
    case .scoreModifier(.double):
      "multiply.square"
    case .action(.freeze):
      "snowflake"
    case .action(.flipThree):
      "arrow.triangle.2.circlepath"
    case .action(.secondChance):
      "shield"
    }
  }
}

extension PlayerRoundStatus {
  var displayName: String {
    switch self {
    case .active:
      "Active"
    case .stayed:
      "Stayed"
    case .busted:
      "Busted"
    case .frozen:
      "Frozen"
    }
  }

  var systemImage: String {
    switch self {
    case .active:
      "circle"
    case .stayed:
      "hand.raised"
    case .busted:
      "xmark.circle"
    case .frozen:
      "snowflake"
    }
  }
}
