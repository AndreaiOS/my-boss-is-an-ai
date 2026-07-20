import Foundation
import Testing
@testable import MyBossCore

@Suite("Story beats")
struct StoryBeatTests {
    private func beat() -> StoryBeat {
        StoryBeat(
            id: "b",
            title: "The Announcement",
            narration: ["human": "H", "ai": "A", "balanced": "B"],
            choices: [
                StoryChoice(label: "Embrace", flavorText: "e", consequence: Consequence(eventID: "e", flavorText: "", automationDelta: 6, humanityDelta: -4)),
                StoryChoice(label: "Resist", flavorText: "r", consequence: Consequence(eventID: "r", flavorText: "", automationDelta: -4, humanityDelta: 4))
            ]
        )
    }

    @Test("narration picks the variant for the lean")
    func narrationByLean() {
        #expect(beat().narration(for: .ai) == "A")
        #expect(beat().narration(for: .human) == "H")
    }

    @Test("a missing variant falls back to balanced")
    func narrationFallback() {
        let b = StoryBeat(id: "b", title: "t", narration: ["balanced": "B"], choices: beat().choices)
        #expect(b.narration(for: .ai) == "B")
    }

    @Test("bundled story.json has the announcement with all three variants")
    func bundled() throws {
        let beats = try StoryBeatCatalog.loadDefault()
        let announcement = try #require(beats.first { $0.id == "the_announcement" })
        for lean in ["human", "ai", "balanced"] {
            #expect(announcement.narration[lean]?.isEmpty == false)
        }
        #expect(announcement.choices.count == 2)
    }
}
