import Foundation
import Testing
@testable import MyBossCore

private func makeCatalog() -> [OfficeTask] {
    (0..<10).map { i in
        OfficeTask(
            id: "t\(i)", title: "T\(i)",
            humanConsequence: Consequence(eventID: "h\(i)", flavorText: "", automationDelta: -10, humanityDelta: 5),
            aiConsequence: Consequence(eventID: "a\(i)", flavorText: "", automationDelta: 10, humanityDelta: -5)
        )
    }
}

private let layoff = OfficeEvent(
    id: "layoff_gino",
    flavorText: "Gino has been optimized.",
    metric: .automation,
    threshold: 20,
    direction: .above,
    undoes: ["gino_rehired"]
)

private let rehire = OfficeEvent(
    id: "gino_rehired",
    flavorText: "Gino is rehired. The mug is reunited with its human.",
    metric: .automation,
    threshold: 10,
    direction: .below,
    undoes: ["layoff_gino"],
    requiresAny: ["layoff_gino"]
)

@Suite("Comeback events")
struct ComebackEventTests {

    @Test("a comeback never fires before the event it reverses")
    func requiresGate() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [layoff, rehire])
        let tasks = engine.startDay()
        // Automation starts at 0, below rehire's threshold — but Gino was
        // never laid off, so nothing must fire.
        let resolution = engine.resolve(tasks[0], with: .human)
        #expect(resolution.events.isEmpty)
    }

    @Test("a comeback reverses the original event and removes its trace")
    func reversal() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [layoff, rehire])
        let tasks = engine.startDay()

        _ = engine.resolve(tasks[0], with: .ai) // automation 10
        let fired = engine.resolve(tasks[1], with: .ai) // automation 20 -> layoff
        #expect(fired.events == [layoff])

        _ = engine.resolve(tasks[2], with: .human) // automation 10
        let comeback = engine.resolve(tasks[3], with: .human) // automation 0 -> rehire
        #expect(comeback.events == [rehire])
        #expect(engine.state.triggeredEventIDs == ["gino_rehired"])
    }

    @Test("the world can oscillate: the original event re-fires after a comeback")
    func oscillation() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [layoff, rehire])
        var tasks = engine.startDay()

        _ = engine.resolve(tasks[0], with: .ai)
        _ = engine.resolve(tasks[1], with: .ai) // layoff fires
        _ = engine.resolve(tasks[2], with: .human)
        _ = engine.resolve(tasks[3], with: .human) // rehire fires
        engine.endDay()

        tasks = engine.startDay()
        _ = engine.resolve(tasks[0], with: .ai) // automation 10
        let again = engine.resolve(tasks[1], with: .ai) // automation 20 -> layoff again
        #expect(again.events == [layoff])
        #expect(engine.state.triggeredEventIDs == ["layoff_gino"])
    }

    @Test("events without comeback fields still decode from plain JSON")
    func backwardCompatibleDecoding() throws {
        let json = """
        [{"id": "e", "flavorText": "t", "metric": "automation", "threshold": 10, "direction": "above"}]
        """.data(using: .utf8)!
        let events = try EventCatalog.decode(from: json)
        #expect(events[0].undoes.isEmpty)
        #expect(events[0].requiresAny.isEmpty)
    }

    @Test("bundled events only reference ids that exist")
    func bundledIntegrity() throws {
        let events = try EventCatalog.loadDefault()
        let ids = Set(events.map(\.id))
        for event in events {
            for referenced in event.undoes + event.requiresAny {
                #expect(ids.contains(referenced), "\(event.id) references missing \(referenced)")
            }
        }
        // The default content includes at least one comeback.
        #expect(events.contains { !$0.requiresAny.isEmpty })
    }
}
