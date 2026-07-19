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

private func makeDuels(count: Int = 6) -> [Duel] {
    (0..<count).map { i in
        Duel(
            id: "duel\(i)",
            opponent: "The Client",
            rounds: (1...3).map { r in
                DuelRound(provocation: "P\(r)", comebacks: ["A", "B", "C"], correctIndex: 1)
            },
            winConsequence: Consequence(eventID: "win\(i)", flavorText: "", automationDelta: 0, humanityDelta: 8),
            loseConsequence: Consequence(eventID: "lose\(i)", flavorText: "", automationDelta: 0, humanityDelta: -6)
        )
    }
}

private func playDay(_ engine: GameEngine) {
    for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
    engine.endDay()
}

private func duelSequence(_ engine: GameEngine) -> [String] {
    var ids: [String] = []
    for _ in 1...7 {
        if let duel = engine.duelForToday() { ids.append(duel.id) }
        playDay(engine)
    }
    return ids
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

    @Test("same seed, same duel order; resume preserves it")
    func duelOrderDeterministic() {
        let duels = makeDuels()
        let a = GameEngine(catalog: makeCatalog(), seed: 9, duels: duels)
        let b = GameEngine(catalog: makeCatalog(), seed: 9, duels: duels)
        let expected = duelSequence(b)
        #expect(duelSequence(a) == expected)
        let resumed = GameEngine(catalog: makeCatalog(), state: GameState(campaignLength: 7, seed: 9), duels: duels)
        #expect(duelSequence(resumed) == expected)
    }

    @Test("different seeds deal duels in a different order")
    func duelOrderVaries() {
        let duels = makeDuels()
        let orders = Set((UInt64(1)...4).map { seed in
            duelSequence(GameEngine(catalog: makeCatalog(), seed: seed, duels: duels)).joined(separator: ",")
        })
        #expect(orders.count > 1)
    }

    @Test("consultant order follows the seed too")
    func consultantOrderDeterministic() {
        let offers = (0..<4).map { i in
            ConsultantOffer(
                id: "offer\(i)", pitch: "P\(i)",
                acceptConsequence: Consequence(eventID: "acc\(i)", flavorText: "", automationDelta: 8, humanityDelta: -3),
                refuseConsequence: Consequence(eventID: "ref\(i)", flavorText: "", automationDelta: -2, humanityDelta: 3)
            )
        }
        func offerSequence(seed: UInt64) -> [String] {
            let engine = GameEngine(catalog: makeCatalog(), seed: seed, consultants: offers)
            var ids: [String] = []
            for _ in 1...7 {
                playDay(engine)
                if let offer = engine.consultantForTonight() { ids.append(offer.id) }
            }
            return ids
        }
        #expect(offerSequence(seed: 11) == offerSequence(seed: 11))
    }
}
