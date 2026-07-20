import Testing
@testable import MyBossCore

@Suite("Share card content")
struct ShareCardContentTests {
    private func ending(_ flavor: String) -> Ending {
        Ending(id: "e", title: "The Great Compromise", flavorText: flavor)
    }
    private var office: OfficeState {
        var o = OfficeState()
        o.apply(Consequence(eventID: "", flavorText: "", automationDelta: 62, humanityDelta: -60))
        return o
    }

    @Test("title is upper-cased and footer is the wordmark")
    func titleAndFooter() {
        let c = ShareCardContent(ending: ending("short"), office: OfficeState(), dailyScore: nil)
        #expect(c.title == "THE GREAT COMPROMISE")
        #expect(c.footer == "My Boss Is an AI")
    }

    @Test("a long tagline is trimmed on a word boundary with an ellipsis")
    func taglineTrim() {
        let long = String(repeating: "word ", count: 40) // 200 chars
        let c = ShareCardContent(ending: ending(long), office: OfficeState(), dailyScore: nil)
        #expect(c.tagline.count <= 91)
        #expect(c.tagline.hasSuffix("…"))
        #expect(!c.tagline.contains("word…word"))
    }

    @Test("short taglines pass through untouched")
    func taglineShort() {
        let c = ShareCardContent(ending: ending("Humans and robots share the mug."), office: OfficeState(), dailyScore: nil)
        #expect(c.tagline == "Humans and robots share the mug.")
    }

    @Test("the score line shows both meters, plus the daily score when set")
    func scoreLine() {
        let plain = ShareCardContent(ending: ending("x"), office: office, dailyScore: nil)
        #expect(plain.scoreLine == "🤖 62  ❤️ 40")
        let daily = ShareCardContent(ending: ending("x"), office: office, dailyScore: 275)
        #expect(daily.scoreLine == "🤖 62  ❤️ 40  ☀️ 275")
    }
}
