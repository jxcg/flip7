import Testing
@testable import Flip7Core

@Test("The MVP ruleset exposes its agreed game limits")
func mvpRulesetLimits() {
    #expect(Ruleset.minimumPlayerCount == 3)
    #expect(Ruleset.maximumPlayerCount == 9)
    #expect(Ruleset.targetScore == 200)
}
