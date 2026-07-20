import Foundation
import Testing
@testable import MyBossCore

@Suite("Daily streak")
struct DailyStreakTests {
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    @Test("the first ever completion starts a streak of one")
    func first() {
        let r = DailyStreak.update(streak: 0, lastDayKey: 0, today: date("2026-07-20T12:00:00Z"))
        #expect(r.streak == 1)
        #expect(r.dayKey == 20260720)
    }

    @Test("finishing again the same day does not change the streak")
    func sameDay() {
        let r = DailyStreak.update(streak: 3, lastDayKey: 20260720, today: date("2026-07-20T22:00:00Z"))
        #expect(r.streak == 3)
    }

    @Test("the next calendar day extends the streak")
    func consecutive() {
        let r = DailyStreak.update(streak: 3, lastDayKey: 20260720, today: date("2026-07-21T08:00:00Z"))
        #expect(r.streak == 4)
        #expect(r.dayKey == 20260721)
    }

    @Test("a gap resets the streak to one")
    func gap() {
        let r = DailyStreak.update(streak: 9, lastDayKey: 20260720, today: date("2026-07-23T08:00:00Z"))
        #expect(r.streak == 1)
    }

    @Test("month boundaries count as consecutive")
    func monthBoundary() {
        let r = DailyStreak.update(streak: 2, lastDayKey: 20260731, today: date("2026-08-01T08:00:00Z"))
        #expect(r.streak == 3)
    }
}
