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
        rounds: [
            DuelRound(provocation: "P1", comebacks: ["a", "b", "c"], correctIndex: 0),
            DuelRound(provocation: "P2", comebacks: ["a", "b", "c"], correctIndex: 1),
            DuelRound(provocation: "P3", comebacks: ["a", "b", "c"], correctIndex: 2)
        ],
        winConsequence: Consequence(eventID: "w", flavorText: "won", automationDelta: -3, humanityDelta: 8),
        loseConsequence: Consequence(eventID: "l", flavorText: "lost", automationDelta: 3, humanityDelta: -6)
    )
}

@Suite("Best-of-three duels")
struct DuelRoundsTests {

    @Test("the bout tracks rounds and ends as soon as one side takes two")
    func earlyExit() {
        var bout = DuelBout(duel: makeDuel())
        #expect(bout.currentRound?.provocation == "P1")
        #expect(!bout.isOver)

        #expect(bout.answer(comebackIndex: 0) == true) // round 1 won
        #expect(bout.currentRound?.provocation == "P2")
        #expect(bout.answer(comebackIndex: 1) == true) // round 2 won -> bout over
        #expect(bout.isOver)
        #expect(bout.won == true)
        #expect(bout.currentRound == nil)
    }

    @Test("two lost rounds end the bout as a loss")
    func lossEarlyExit() {
        var bout = DuelBout(duel: makeDuel())
        #expect(bout.answer(comebackIndex: 2) == false)
        #expect(bout.answer(comebackIndex: 2) == false)
        #expect(bout.isOver)
        #expect(bout.won == false)
    }

    @Test("a split goes to the third round")
    func fullThreeRounds() {
        var bout = DuelBout(duel: makeDuel())
        _ = bout.answer(comebackIndex: 0) // win
        _ = bout.answer(comebackIndex: 0) // lose
        #expect(!bout.isOver)
        _ = bout.answer(comebackIndex: 2) // win
        #expect(bout.isOver)
        #expect(bout.won == true)
    }

    @Test("the engine applies the bout outcome")
    func engineOutcome() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, duels: [makeDuel()])
        let won = engine.resolve(makeDuel(), won: true)
        #expect(won.consequence == makeDuel().winConsequence)
        let lost = engine.resolve(makeDuel(), won: false)
        #expect(lost.consequence == makeDuel().loseConsequence)
    }

    @Test("bundled duels have 3 valid rounds each and at least 6 duels")
    func bundled() throws {
        let duels = try DuelCatalog.loadDefault()
        #expect(duels.count >= 6)
        #expect(Set(duels.map(\.id)).count == duels.count)
        for duel in duels {
            #expect(duel.rounds.count == 3)
            for round in duel.rounds {
                #expect(round.comebacks.count >= 3)
                #expect(round.comebacks.indices.contains(round.correctIndex))
            }
        }
    }
}

@Suite("Daily challenge seed")
struct DailySeedTests {

    @Test("same calendar day gives the same seed on any device")
    func deterministic() {
        let noon = ISO8601DateFormatter().date(from: "2026-07-18T12:00:00Z")!
        let evening = ISO8601DateFormatter().date(from: "2026-07-18T22:30:00Z")!
        #expect(DailySeed.seed(for: noon) == DailySeed.seed(for: evening))
    }

    @Test("different days give different seeds")
    func varies() {
        let today = ISO8601DateFormatter().date(from: "2026-07-18T12:00:00Z")!
        let tomorrow = ISO8601DateFormatter().date(from: "2026-07-19T12:00:00Z")!
        #expect(DailySeed.seed(for: today) != DailySeed.seed(for: tomorrow))
    }
}
