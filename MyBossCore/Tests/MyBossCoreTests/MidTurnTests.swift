import Foundation
import Testing
@testable import MyBossCore

@Suite("Mid-turn beat")
struct MidTurnTests {
    private func catalog() -> [OfficeTask] {
        (0..<10).map { i in OfficeTask(id: "t\(i)", title: "T", humanConsequence: Consequence(eventID: "h", flavorText: "", automationDelta: -3, humanityDelta: 4), aiConsequence: Consequence(eventID: "a", flavorText: "", automationDelta: 5, humanityDelta: -4)) }
    }
    private func beat() -> StoryBeat {
        StoryBeat(id: "the_announcement", title: "T",
            narration: ["balanced": "B"],
            choices: [StoryChoice(label: "x", flavorText: "", consequence: Consequence(eventID: "c", flavorText: "", automationDelta: 6, humanityDelta: 0))])
    }
    private func play(_ e: GameEngine) { for t in e.startDay() { _ = e.resolve(t, with: .ai) }; e.endDay() }

    @Test("the beat is offered only on day 3")
    func onlyDay3() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        #expect(e.midTurnBeat() == nil)          // day 1
        play(e); #expect(e.midTurnBeat() == nil) // day 2
        play(e); #expect(e.midTurnBeat()?.id == "the_announcement") // day 3
    }

    @Test("resolving records it so it never fires twice")
    func firesOnce() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e) // day 3
        _ = e.resolve(beat(), choice: beat().choices[0])
        #expect(e.state.shownBeatIDs.contains("the_announcement"))
        #expect(e.midTurnBeat() == nil)
    }

    @Test("the choice consequence moves the office")
    func choiceApplies() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e)
        let before = e.state.office.automation
        _ = e.resolve(beat(), choice: beat().choices[0])
        #expect(e.state.office.automation == before + 6)
    }

    @Test("shownBeatIDs survives a save/restore")
    func persists() throws {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e)
        _ = e.resolve(beat(), choice: beat().choices[0])
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(e.state))
        #expect(saved.shownBeatIDs.contains("the_announcement"))
    }
}
