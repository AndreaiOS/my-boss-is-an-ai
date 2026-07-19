import Foundation
import Testing
@testable import MyBossCore

private func makeCatalog() -> [OfficeTask] {
    (0..<10).map { i in
        OfficeTask(
            id: "t\(i)", title: "T\(i)",
            humanConsequence: Consequence(eventID: "h\(i)", flavorText: "", automationDelta: -3, humanityDelta: 4),
            aiConsequence: Consequence(eventID: "a\(i)", flavorText: "", automationDelta: 5, humanityDelta: -4)
        )
    }
}

private func makeDuel() -> Duel {
    Duel(
        id: "d1",
        opponent: "The Client",
        rounds: [DuelRound(provocation: "P", comebacks: ["a", "b", "c"], correctIndex: 0)],
        winConsequence: Consequence(eventID: "w", flavorText: "", automationDelta: 0, humanityDelta: 0),
        loseConsequence: Consequence(eventID: "l", flavorText: "", automationDelta: 0, humanityDelta: 0)
    )
}

@Suite("Daily challenge scoring")
struct DailyChallengeTests {

    @Test("won bouts are counted in the state, lost ones are not")
    func duelsWonTracking() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, duels: [makeDuel()])
        #expect(engine.state.duelsWon == 0)
        _ = engine.resolve(makeDuel(), won: true)
        #expect(engine.state.duelsWon == 1)
        _ = engine.resolve(makeDuel(), won: false)
        #expect(engine.state.duelsWon == 1)
        _ = engine.resolve(makeDuel(), won: true)
        #expect(engine.state.duelsWon == 2)
    }

    @Test("the daily score rewards humanity and duel wins")
    func score() {
        var state = GameState(campaignLength: 7)
        #expect(state.dailyScore == 200) // humanity starts at 100
        state.duelsWon = 3
        #expect(state.dailyScore == 275)
    }

    @Test("a v1.0 save without duelsWon still loads")
    func legacyDecode() throws {
        let legacy = """
        {
          "day": 4,
          "campaignLength": 7,
          "office": { "automation": 55, "humanity": 62 },
          "triggeredEventIDs": ["gino_fired"]
        }
        """
        let state = try JSONDecoder().decode(GameState.self, from: Data(legacy.utf8))
        #expect(state.day == 4)
        #expect(state.duelsWon == 0)
        #expect(state.office.humanity == 62)
    }
}
