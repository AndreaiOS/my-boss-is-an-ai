import Testing
@testable import MyBossCore

@Suite("Notebook content")
struct NotebookContentTests {
    private let catalog = [
        Ending(id: "a", title: "A", flavorText: ""),
        Ending(id: "b", title: "B", flavorText: ""),
        Ending(id: "c", title: "C", flavorText: "")
    ]

    @Test("found flags follow the found set, order is preserved")
    func mapping() {
        let rows = NotebookContent.endings(catalog, found: ["a", "c"])
        #expect(rows.map(\.id) == ["a", "b", "c"])
        #expect(rows.map(\.found) == [true, false, true])
    }

    @Test("nothing found yields all-locked rows")
    func empty() {
        let rows = NotebookContent.endings(catalog, found: [])
        #expect(rows.allSatisfy { !$0.found })
    }
}
