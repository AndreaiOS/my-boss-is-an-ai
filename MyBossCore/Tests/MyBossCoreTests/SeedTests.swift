import Foundation
import Testing
@testable import MyBossCore

private func makeCatalog(count: Int = 10) -> [OfficeTask] {
    (0..<count).map { i in
        OfficeTask(
            id: "t\(i)", title: "T\(i)",
            humanConsequence: Consequence(eventID: "h\(i)", flavorText: "", automationDelta: -3, humanityDelta: 4),
            aiConsequence: Consequence(eventID: "a\(i)", flavorText: "", automationDelta: 5, humanityDelta: -4)
        )
    }
}

@Suite("Persisted campaign seed")
struct SeedTests {

    @Test("the seed survives encode/decode")
    func roundTrip() throws {
        let state = GameState(campaignLength: 7, seed: 42)
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        #expect(back.seed == 42)
    }

    @Test("legacy saves without a seed still load")
    func legacyDecode() throws {
        let legacy = """
        {"day": 2, "campaignLength": 7, "office": {"automation": 10, "humanity": 90}, "triggeredEventIDs": []}
        """
        let state = try JSONDecoder().decode(GameState.self, from: Data(legacy.utf8))
        #expect(state.day == 2) // seed gets a random default, no crash
    }

    @Test("a fresh engine stores its seed in the state")
    func engineStoresSeed() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 7)
        #expect(engine.state.seed == 7)
    }
}
