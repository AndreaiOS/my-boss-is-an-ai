import Foundation
import MyBossCore

/// The daily challenge: one campaign a day, same seed for everyone on the
/// same UTC day, score on the `daily_challenge` leaderboard. The active-run
/// flag lives in UserDefaults so a quit-and-resume still counts as a daily.
enum DailyChallenge {
    private static let key = "dailyRunDay"

    private static var todayStamp: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year!)-\(parts.month!)-\(parts.day!)"
    }

    static func begin() {
        UserDefaults.standard.set(todayStamp, forKey: key)
    }

    /// True while today's daily run is in progress. A flag left over from
    /// another day is stale: the run expired with its seed.
    static var isActiveToday: Bool {
        UserDefaults.standard.string(forKey: key) == todayStamp
    }

    static func end() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
