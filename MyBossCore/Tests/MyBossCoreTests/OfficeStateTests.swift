import Foundation
import Testing
@testable import MyBossCore

@Suite("OfficeState")
struct OfficeStateTests {

    @Test("starts balanced: zero automation, full humanity")
    func initialState() {
        let state = OfficeState()
        #expect(state.automation == 0)
        #expect(state.humanity == 100)
        #expect(state.stage == .lively)
    }

    @Test("applying a consequence shifts automation and humanity")
    func applyConsequence() {
        var state = OfficeState()
        let consequence = Consequence(
            eventID: "robot_cleaner_appears",
            flavorText: "A Roomba with googly eyes replaces Gino the janitor.",
            automationDelta: 15,
            humanityDelta: -10
        )
        state.apply(consequence)
        #expect(state.automation == 15)
        #expect(state.humanity == 90)
    }

    @Test("scores are clamped to 0...100")
    func clamping() {
        var state = OfficeState()
        let extreme = Consequence(
            eventID: "singularity",
            flavorText: "The coffee machine achieves consciousness.",
            automationDelta: 999,
            humanityDelta: -999
        )
        state.apply(extreme)
        #expect(state.automation == 100)
        #expect(state.humanity == 0)

        let recovery = Consequence(
            eventID: "team_pizza",
            flavorText: "Someone brings pizza. Morale skyrockets.",
            automationDelta: -999,
            humanityDelta: 999
        )
        state.apply(recovery)
        #expect(state.automation == 0)
        #expect(state.humanity == 100)
    }

    @Test("stage reflects the automation/humanity balance")
    func stageDerivation() {
        var lively = OfficeState()
        lively.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 10, humanityDelta: 0))
        #expect(lively.stage == .lively)

        var hybrid = OfficeState()
        hybrid.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 45, humanityDelta: 0))
        #expect(hybrid.stage == .hybrid)

        var automated = OfficeState()
        automated.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 75, humanityDelta: 0))
        #expect(automated.stage == .automated)
    }

    @Test("office state round-trips through Codable for local save")
    func codableRoundTrip() throws {
        var state = OfficeState()
        state.apply(Consequence(eventID: "e", flavorText: "", automationDelta: 30, humanityDelta: -20))
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OfficeState.self, from: data)
        #expect(decoded == state)
    }
}
