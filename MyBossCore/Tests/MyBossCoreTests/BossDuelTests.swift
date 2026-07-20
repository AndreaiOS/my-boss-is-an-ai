import Foundation
import Testing
@testable import MyBossCore

@Suite("Boss duel climax")
struct BossDuelTests {
    private func catalog() -> [OfficeTask] {
        (0..<10).map { i in OfficeTask(id: "t\(i)", title: "T", humanConsequence: Consequence(eventID: "h", flavorText: "", automationDelta: -3, humanityDelta: 4), aiConsequence: Consequence(eventID: "a", flavorText: "", automationDelta: 5, humanityDelta: -4)) }
    }
    private func boss() -> Duel {
        Duel(id: "boss", opponent: "The Boss-AI",
            rounds: (1...3).map { DuelRound(provocation: "P\($0)", comebacks: ["a", "b", "c"], correctIndex: 1) },
            winConsequence: Consequence(eventID: "bw", flavorText: "", automationDelta: -6, humanityDelta: 14),
            loseConsequence: Consequence(eventID: "bl", flavorText: "", automationDelta: 10, humanityDelta: -10))
    }
    private func play(_ e: GameEngine) { for t in e.startDay() { _ = e.resolve(t, with: .ai) }; e.endDay() }

    @Test("the boss duel is scheduled only on the last day")
    func lastDayOnly() {
        let e = GameEngine(catalog: catalog(), seed: 1, campaignLength: 7, bossDuel: boss())
        for _ in 1...6 { #expect(e.bossDuelForToday() == nil); play(e) }
        #expect(e.bossDuelForToday()?.id == "boss") // day 7
    }

    @Test("winning vs losing the boss duel changes the final scores")
    func tiltsEnding() {
        func finalHumanity(won: Bool) -> Int {
            let e = GameEngine(catalog: catalog(), seed: 1, campaignLength: 7, bossDuel: boss())
            for _ in 1...6 { play(e) }
            _ = e.resolve(boss(), won: won)
            return e.state.office.humanity
        }
        #expect(finalHumanity(won: true) > finalHumanity(won: false))
    }

    @Test("bundled boss loads with three valid rounds")
    func bundled() throws {
        let boss = try DuelCatalog.loadBoss()
        #expect(boss.rounds.count == 3)
        for r in boss.rounds { #expect(r.comebacks.indices.contains(r.correctIndex)) }
    }
}
