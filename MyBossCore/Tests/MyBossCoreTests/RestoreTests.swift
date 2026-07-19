import Foundation
import Testing
@testable import MyBossCore

@Suite("Save restore")
struct RestoreTests {

    @Test("engine resumes from a previously saved state")
    func resumeFromSave() throws {
        let catalog = (0..<10).map { i in
            OfficeTask(
                id: "t\(i)", title: "T\(i)",
                humanConsequence: Consequence(eventID: "h\(i)", flavorText: "", automationDelta: -5, humanityDelta: 5),
                aiConsequence: Consequence(eventID: "a\(i)", flavorText: "", automationDelta: 10, humanityDelta: -5)
            )
        }
        let original = GameEngine(catalog: catalog, seed: 3)
        for task in original.startDay() { _ = original.resolve(task, with: .ai) }
        original.endDay()

        let data = try JSONEncoder().encode(original.state)
        let saved = try JSONDecoder().decode(GameState.self, from: data)

        let resumed = GameEngine(catalog: catalog, state: saved)
        #expect(resumed.state == original.state)
        #expect(resumed.state.day == 2)

        let tasks = resumed.startDay()
        #expect((3...5).contains(tasks.count))
    }
}
