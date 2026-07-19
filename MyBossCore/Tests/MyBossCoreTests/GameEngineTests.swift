import Foundation
import Testing
@testable import MyBossCore

private func makeCatalog(count: Int = 10) -> [OfficeTask] {
    (0..<count).map { i in
        OfficeTask(
            id: "task_\(i)",
            title: "Task \(i)",
            humanConsequence: Consequence(
                eventID: "human_\(i)", flavorText: "You did it yourself. Slowly. With love.",
                automationDelta: -5, humanityDelta: 5
            ),
            aiConsequence: Consequence(
                eventID: "ai_\(i)", flavorText: "The AI did it in 0.3s and also filed your taxes.",
                automationDelta: 10, humanityDelta: -5
            )
        )
    }
}

@Suite("GameEngine")
struct GameEngineTests {

    @Test("a workday offers between 3 and 5 unique tasks")
    func dayTaskCount() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 42)
        let tasks = engine.startDay()
        #expect((3...5).contains(tasks.count))
        #expect(Set(tasks.map(\.id)).count == tasks.count)
    }

    @Test("same seed produces the same workday")
    func determinism() {
        let a = GameEngine(catalog: makeCatalog(), seed: 7).startDay()
        let b = GameEngine(catalog: makeCatalog(), seed: 7).startDay()
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test("choosing AI applies the AI consequence to the office")
    func aiChoice() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1)
        let task = engine.startDay()[0]
        let resolution = engine.resolve(task, with: .ai)
        #expect(resolution.consequence == task.aiConsequence)
        #expect(engine.state.office.automation == 10)
        #expect(engine.state.office.humanity == 95)
    }

    @Test("choosing Human applies the human consequence to the office")
    func humanChoice() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1)
        let task = engine.startDay()[0]
        let resolution = engine.resolve(task, with: .human)
        #expect(resolution.consequence == task.humanConsequence)
        #expect(engine.state.office.automation == 0)
        #expect(engine.state.office.humanity == 100)
    }

    @Test("ending the day advances the day counter")
    func endDay() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1)
        #expect(engine.state.day == 1)
        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay()
        #expect(engine.state.day == 2)
    }

    @Test("campaign finishes after the configured number of days")
    func campaignEnd() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, campaignLength: 2)
        for _ in 0..<2 {
            for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
            engine.endDay()
        }
        #expect(engine.state.isFinished)
    }

    @Test("game state round-trips through Codable for local save")
    func saveRoundTrip() throws {
        let engine = GameEngine(catalog: makeCatalog(), seed: 9)
        for task in engine.startDay() { _ = engine.resolve(task, with: .human) }
        engine.endDay()
        let data = try JSONEncoder().encode(engine.state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == engine.state)
    }
}

@Suite("TaskCatalog")
struct TaskCatalogTests {

    @Test("decodes tasks from JSON data")
    func decodeFromJSON() throws {
        let json = """
        [
          {
            "id": "reply_emails",
            "title": "Reply to 47 unread emails",
            "humanConsequence": {
              "eventID": "human_emails",
              "flavorText": "You typed 'Best regards' 47 times. Your soul left twice.",
              "automationDelta": -5,
              "humanityDelta": 5
            },
            "aiConsequence": {
              "eventID": "ai_emails",
              "flavorText": "The AI replied to everyone, including your mom.",
              "automationDelta": 10,
              "humanityDelta": -5
            }
          }
        ]
        """.data(using: .utf8)!
        let tasks = try TaskCatalog.decode(from: json)
        #expect(tasks.count == 1)
        #expect(tasks[0].id == "reply_emails")
        #expect(tasks[0].aiConsequence.eventID == "ai_emails")
    }

    @Test("bundled default catalog loads and has enough tasks for a campaign")
    func bundledCatalog() throws {
        let tasks = try TaskCatalog.loadDefault()
        // 7 days × up to 5 tasks = 35 slots: ≥36 guarantees no repeats.
        #expect(tasks.count >= 36)
        #expect(Set(tasks.map(\.id)).count == tasks.count)
    }
}
