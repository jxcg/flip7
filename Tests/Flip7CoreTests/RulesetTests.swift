import Testing

@testable import Flip7Core

@Test("The base ruleset exposes its agreed numeric limits")
func baseRulesetLimits() {
  #expect(Ruleset.minimumPlayerCount == 3)
  #expect(Ruleset.maximumPlayerCount == 9)
  #expect(Ruleset.targetScore == 200)
  #expect(Ruleset.flipSevenNumberCount == 7)
  #expect(Ruleset.flipSevenBonus == 15)
}
