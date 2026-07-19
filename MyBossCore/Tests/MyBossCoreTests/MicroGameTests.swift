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

@Suite("Micro-game hook")
struct MicroGameTests {

    @Test("the bonus nudges humanity up without touching automation")
    func bonus() {
        let engine = GameEngine(catalog: makeCatalog(), seed: 1)
        _ = engine.resolve(engine.startDay()[0], with: .ai) // dip humanity below 100
        let before = engine.state.office.humanity
        let resolution = engine.resolveMicroGameBonus()
        #expect(engine.state.office.humanity == min(100, before + 2))
        #expect(resolution.consequence.automationDelta == 0)
    }

    @Test("tasks can declare a micro-game and default to none")
    func decoding() throws {
        let json = """
        [{"id": "x", "title": "X",
          "microGame": "printer_smash",
          "humanConsequence": {"eventID": "h", "flavorText": "", "automationDelta": 0, "humanityDelta": 0},
          "aiConsequence": {"eventID": "a", "flavorText": "", "automationDelta": 0, "humanityDelta": 0}}]
        """
        let tasks = try TaskCatalog.decode(from: Data(json.utf8))
        #expect(tasks[0].microGame == "printer_smash")
        #expect(makeCatalog()[0].microGame == nil)
    }

    @Test("bundled tasks map the three launch micro-games")
    func bundledMapping() throws {
        let tasks = try TaskCatalog.loadDefault()
        let games = tasks.compactMap(\.microGame)
        #expect(Set(games).isSuperset(of: ["printer_smash", "coffee_rush", "find_lasagna"]))
    }

    @Test("Resolution can be built by the presentation layer")
    func resolutionInit() {
        let consequence = Consequence(eventID: "c", flavorText: "", automationDelta: 0, humanityDelta: 0)
        let resolution = Resolution(consequence: consequence, events: [])
        #expect(resolution.consequence == consequence)
    }
}
