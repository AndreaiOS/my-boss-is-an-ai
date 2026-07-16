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

private let singularity = Ending(
    id: "singularity", title: "The Corporate Singularity", flavorText: "beep boop",
    minAutomation: 70, maxHumanity: 30
)
private let hybrid = Ending(
    id: "hybrid", title: "The Great Compromise", flavorText: "half and half",
    minAutomation: 40, maxAutomation: 69
)
private let fallback = Ending(
    id: "fallback", title: "Just Another Quarter", flavorText: "meh"
)

@Suite("Ending")
struct EndingTests {

    @Test("bounds are inclusive and absent bounds are unbounded")
    func matching() {
        var office = OfficeState()
        // automation 0, humanity 100
        #expect(!singularity.matches(office))
        #expect(fallback.matches(office))

        office.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 70, humanityDelta: -70))
        // automation 70, humanity 30 — inclusive on both edges
        #expect(singularity.matches(office))
    }

    @Test("the first matching ending in catalog order wins")
    func firstMatchWins() {
        let endings = [singularity, hybrid, fallback]
        var office = OfficeState()
        office.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 50, humanityDelta: 0))
        let chosen = endings.first { $0.matches(office) }
        #expect(chosen == hybrid)
    }

    @Test("the engine has no finale until the campaign is over")
    func finaleTiming() {
        let engine = GameEngine(
            catalog: makeCatalog(), seed: 1, campaignLength: 1,
            endings: [singularity, hybrid, fallback]
        )
        #expect(engine.finale() == nil)
        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay()
        #expect(engine.state.isFinished)
        #expect(engine.finale() == fallback)
    }

    @Test("endings decode from JSON with optional bounds")
    func decoding() throws {
        let json = """
        [{"id": "e1", "title": "T", "flavorText": "f", "minAutomation": 70},
         {"id": "e2", "title": "U", "flavorText": "g"}]
        """.data(using: .utf8)!
        let endings = try EndingCatalog.decode(from: json)
        #expect(endings[0].minAutomation == 70)
        #expect(endings[0].maxAutomation == nil)
        #expect(endings[1].minAutomation == nil)
    }

    @Test("every possible final score has an ending")
    func fullCoverage() throws {
        let endings = try EndingCatalog.loadDefault()
        #expect(endings.count >= 5)
        #expect(Set(endings.map(\.id)).count == endings.count)
        for automation in 0...100 {
            for humanity in 0...100 {
                let covered = endings.contains { $0.matches(automation: automation, humanity: humanity) }
                #expect(covered, "no ending for automation \(automation), humanity \(humanity)")
                if !covered { return }
            }
        }
    }
}
