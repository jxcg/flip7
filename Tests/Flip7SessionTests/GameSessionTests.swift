import Flip7Core
import Testing

@testable import Flip7Session

@MainActor
@Test("A seeded session plays from setup to a final result")
func seededSessionCompletesGame() throws {
  let roundOne: [CardKind] = [
    .action(.freeze), .number(.one), .number(.two),
    .scoreModifier(.double), .scoreModifier(.additive(.ten)),
    .number(.eleven), .number(.ten), .number(.nine),
    .number(.eight), .number(.seven), .number(.six),
  ]
  let roundTwo: [CardKind] = [
    .number(.three), .number(.four), .number(.twelve),
    .number(.eleven), .number(.ten), .number(.nine),
    .number(.eight), .number(.seven), .number(.six),
  ]
  let cards = (roundOne + roundTwo).enumerated().map {
    GameCard(id: CardID(rawValue: $0.offset), kind: $0.element)
  }
  let winnerID = PlayerID(rawValue: 1)
  let frozenPlayerID = PlayerID(rawValue: 2)
  let session = GameSession()

  #expect(session.start(with: Deck(drawPile: cards)))
  var checkedStaleInput = false
  var resolvedAction = false
  var roundsAnnounced: Set<Int> = []

  for _ in 0..<100 {
    if let outcome = session.turnOutcome,
      outcome.messages.contains(where: {
        $0.hasPrefix("Round ") && $0.hasSuffix(" started.")
      })
    {
      // turnOutcome no longer gates play, so it can be observed more than once
      // per round. Collect round numbers rather than counting sightings.
      roundsAnnounced.insert(session.state?.roundNumber ?? 0)
    }

    let state = try #require(session.state)
    switch state.phase {
    case .awaitingTurn(let playerID):
      let inputVersion = session.inputVersion
      if playerID == winnerID {
        session.hit(playerID, inputVersion: inputVersion)
      } else {
        session.stay(playerID, inputVersion: inputVersion)
      }
    case .roundComplete:
      session.startNextRound(inputVersion: session.inputVersion)
    case .awaitingAction(let decision):
      #expect(decision.card.kind == .action(.freeze))
      let staleInputVersion = session.inputVersion
      session.chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: frozenPlayerID,
        inputVersion: staleInputVersion
      )

      let stateAfterAction = session.state
      let inputVersionAfterAction = session.inputVersion
      session.chooseActionTarget(
        cardID: decision.card.id,
        targetPlayerID: frozenPlayerID,
        inputVersion: staleInputVersion
      )
      #expect(session.state == stateAfterAction)
      #expect(session.inputVersion == inputVersionAfterAction)
      #expect(session.commandError == nil)
      checkedStaleInput = true
      resolvedAction = true
    case .gameComplete(let result):
      #expect(result.winnerIDs == [winnerID])
      #expect(result.winningScore == 209)
      #expect(checkedStaleInput)
      #expect(resolvedAction)
      #expect(roundsAnnounced == [1, 2])
      return
    case .waitingToStartRound, .dealingOpeningCards:
      Issue.record("The engine left a transient phase visible")
      return
    }
  }

  Issue.record("The seeded game did not finish")
}
