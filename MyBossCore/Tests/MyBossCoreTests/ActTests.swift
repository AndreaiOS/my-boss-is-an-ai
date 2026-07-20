import Testing
@testable import MyBossCore

@Suite("Acts and lean")
struct ActTests {
    @Test("days map to the 2-3-2 act skeleton")
    func actBoundaries() {
        #expect(Act(for: 1) == .setup)
        #expect(Act(for: 2) == .setup)
        #expect(Act(for: 3) == .escalation)
        #expect(Act(for: 5) == .escalation)
        #expect(Act(for: 6) == .climax)
        #expect(Act(for: 7) == .climax)
    }

    @Test("out-of-range days clamp to the nearest act")
    func actClamp() {
        #expect(Act(for: 0) == .setup)
        #expect(Act(for: 99) == .climax)
    }

    private func office(auto: Int, human: Int) -> OfficeState {
        var o = OfficeState()
        o.apply(Consequence(eventID: "", flavorText: "", automationDelta: auto, humanityDelta: human - 100))
        return o
    }

    @Test("lean reads the accumulated scores")
    func lean() {
        #expect(Lean.from(office(auto: 70, human: 20)) == .ai)
        #expect(Lean.from(office(auto: 10, human: 90)) == .human)
        #expect(Lean.from(office(auto: 45, human: 55)) == .balanced)
    }
}
