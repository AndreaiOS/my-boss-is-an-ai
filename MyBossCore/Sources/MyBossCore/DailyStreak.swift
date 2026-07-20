import Foundation

/// Tracks consecutive daily-challenge days. Day identity is the UTC calendar
/// day, so the streak is stable regardless of the player's timezone or clock.
public enum DailyStreak {
    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    public static func dayKey(for date: Date) -> Int {
        let p = utc.dateComponents([.year, .month, .day], from: date)
        return p.year! * 10000 + p.month! * 100 + p.day!
    }

    public static func update(streak: Int, lastDayKey: Int, today: Date) -> (streak: Int, dayKey: Int) {
        let key = dayKey(for: today)
        if key == lastDayKey { return (streak, key) }
        if lastDayKey != 0,
           let last = date(fromKey: lastDayKey),
           let next = utc.date(byAdding: .day, value: 1, to: last),
           dayKey(for: next) == key {
            return (streak + 1, key)
        }
        return (1, key)
    }

    private static func date(fromKey key: Int) -> Date? {
        var c = DateComponents()
        c.year = key / 10000
        c.month = (key / 100) % 100
        c.day = key % 100
        return utc.date(from: c)
    }
}
