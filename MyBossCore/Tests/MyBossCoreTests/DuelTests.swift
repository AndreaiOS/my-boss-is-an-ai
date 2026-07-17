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

private func makeDuels(count: Int = 3) -> [Duel] {
    (0..<count).map { i in
        Duel(
            id: "duel\(i)",
            opponent: "The Client",
            provocation: "We need to be more agile and disruptive!",
            comebacks: ["A", "B", "C"],
            correctIndex: 1,
            winConsequence: Consequence(eventID: "win\(i)", flavorText: "You win.", automationDelta: 0, humanityDelta: 8),
            loseConsequence: Consequence(eventID: "lose\(i)", flavorText: "You lose.", automationDelta: 0, humanityDelta: -6)
        )
    }
}

@Suite("Meeting duels")
struct DuelTests {

    @Test("no duel on day one, a deterministic one on even days")
    func schedule() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, duels: makeDuels())
        #expect(engine.duelForToday() == nil)

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay()
        let day2 = engine.duelForToday()
        #expect(day2 == makeDuels()[0])

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay()
        #expect(engine.duelForToday() == nil) // day 3

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay()
        #expect(engine.duelForToday() == makeDuels()[1]) // day 4 rotates
    }

    @Test("the right comeback wins, any other loses")
    func resolution() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, duels: makeDuels())
        let duel = makeDuels()[0]

        let won = engine.resolve(duel, comebackIndex: 1)
        #expect(won.consequence == duel.winConsequence)
        #expect(engine.state.office.humanity == 100) // clamped at 100

        let lost = engine.resolve(duel, comebackIndex: 0)
        #expect(lost.consequence == duel.loseConsequence)
        #expect(engine.state.office.humanity == 94)
    }

    @Test("duels can trigger office events too")
    func duelEvents() {
        let event = OfficeEvent(
            id: "morale_drop", flavorText: "", metric: .humanity, threshold: 95, direction: .below
        )
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, events: [event], duels: makeDuels())
        let resolution = engine.resolve(makeDuels()[0], comebackIndex: 0)
        #expect(resolution.events == [event])
    }

    @Test("bundled duels load with valid correct indices")
    func bundled() throws {
        let duels = try DuelCatalog.loadDefault()
        #expect(duels.count >= 4)
        #expect(Set(duels.map(\.id)).count == duels.count)
        for duel in duels {
            #expect(duel.comebacks.count >= 3)
            #expect(duel.comebacks.indices.contains(duel.correctIndex))
        }
    }
}

@Suite("Consultant visits")
struct ConsultantTests {

    private func makeOffers(count: Int = 2) -> [ConsultantOffer] {
        (0..<count).map { i in
            ConsultantOffer(
                id: "offer\(i)",
                pitch: "Buy my AI Transformation Package!",
                acceptConsequence: Consequence(eventID: "acc\(i)", flavorText: "Deal.", automationDelta: 8, humanityDelta: -3),
                refuseConsequence: Consequence(eventID: "ref\(i)", flavorText: "Door.", automationDelta: -2, humanityDelta: 3)
            )
        }
    }

    @Test("the consultant knocks before odd days from day 3 on")
    func schedule() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, consultants: makeOffers())
        #expect(engine.consultantForTonight() == nil) // day 1

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay() // now day 2
        #expect(engine.consultantForTonight() == nil)

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay() // now day 3
        #expect(engine.consultantForTonight() == makeOffers()[0])

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay() // day 4
        #expect(engine.consultantForTonight() == nil)

        for task in engine.startDay() { _ = engine.resolve(task, with: .ai) }
        engine.endDay() // day 5 rotates
        #expect(engine.consultantForTonight() == makeOffers()[1])
    }

    @Test("accepting and refusing apply their consequences")
    func resolution() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1, consultants: makeOffers())
        let offer = makeOffers()[0]

        let accepted = engine.resolve(offer, accepted: true)
        #expect(accepted.consequence == offer.acceptConsequence)
        #expect(engine.state.office.automation == 8)

        let refused = engine.resolve(offer, accepted: false)
        #expect(refused.consequence == offer.refuseConsequence)
        #expect(engine.state.office.automation == 6)
    }

    @Test("bundled consultant offers load")
    func bundled() throws {
        let offers = try ConsultantCatalog.loadDefault()
        #expect(offers.count >= 3)
        #expect(Set(offers.map(\.id)).count == offers.count)
    }
}
