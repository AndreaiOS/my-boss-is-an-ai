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

private let robotCleaner = OfficeEvent(
    id: "robot_cleaner",
    flavorText: "A robot cleaner rolls in. It beeps disapprovingly at your desk.",
    metric: .automation,
    threshold: 10,
    direction: .above
)

private let memesDie = OfficeEvent(
    id: "memes_die",
    flavorText: "Nobody laughs at the memes anymore.",
    metric: .humanity,
    threshold: 95,
    direction: .below
)

@Suite("OfficeEvent")
struct OfficeEventTests {

    @Test("an event fires once when its threshold is crossed")
    func firesOnceWhenCrossed() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [robotCleaner])
        let tasks = engine.startDay()

        // First AI task: automation 5, below threshold — no event.
        let first = engine.resolve(tasks[0], with: .ai)
        #expect(first.events.isEmpty)

        // Second AI task: automation 10, threshold crossed — event fires.
        let second = engine.resolve(tasks[1], with: .ai)
        #expect(second.events == [robotCleaner])

        // Third AI task: still above threshold — but the event never repeats.
        let third = engine.resolve(tasks[2], with: .ai)
        #expect(third.events.isEmpty)
    }

    @Test("falling-metric events fire when the score drops below the threshold")
    func fallingEvent() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [memesDie])
        let tasks = engine.startDay()
        let resolution = engine.resolve(tasks[0], with: .ai) // humanity 100 -> 96... not below 95
        #expect(resolution.events.isEmpty)
        let next = engine.resolve(tasks[1], with: .ai) // humanity 92, below 95
        #expect(next.events == [memesDie])
    }

    @Test("triggered events survive save and restore")
    func persistence() throws {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [robotCleaner])
        let tasks = engine.startDay()
        _ = engine.resolve(tasks[0], with: .ai)
        _ = engine.resolve(tasks[1], with: .ai) // fires robot_cleaner

        let data = try JSONEncoder().encode(engine.state)
        let saved = try JSONDecoder().decode(GameState.self, from: data)
        let resumed = GameEngine(catalog: makeCatalog(), seed: 2, state: saved, events: [robotCleaner])

        // Already triggered before saving: must not fire again after restore.
        let tasks2 = resumed.startDay()
        let resolution = resumed.resolve(tasks2[0], with: .ai)
        #expect(resolution.events.isEmpty)
    }

    @Test("bundled default events load and have unique ids")
    func bundledEvents() throws {
        let events = try EventCatalog.loadDefault()
        #expect(events.count >= 5)
        #expect(Set(events.map(\.id)).count == events.count)
    }
}

@Suite("Campaign balance")
struct BalanceTests {

    private func simulate(choice: WorkChoice, seed: UInt64) -> (midStage: OfficeStage, finalStage: OfficeStage) {
        let catalog = (try? TaskCatalog.loadDefault()) ?? []
        let engine = GameEngine(catalog: catalog, seed: seed)
        var midStage = OfficeStage.lively
        while !engine.state.isFinished {
            for task in engine.startDay() { _ = engine.resolve(task, with: choice) }
            if engine.state.day == 2 { midStage = engine.state.office.stage }
            engine.endDay()
        }
        return (midStage, engine.state.office.stage)
    }

    @Test("a full-AI campaign reaches the automated office, but not before day 3", arguments: [1, 42, 999] as [UInt64])
    func fullAIArc(seed: UInt64) {
        let (midStage, finalStage) = simulate(choice: .ai, seed: seed)
        #expect(midStage != .automated)
        #expect(finalStage == .automated)
    }

    @Test("a full-human campaign keeps the office lively", arguments: [1, 42, 999] as [UInt64])
    func fullHumanStaysLively(seed: UInt64) {
        let (_, finalStage) = simulate(choice: .human, seed: seed)
        #expect(finalStage == .lively)
    }
}
