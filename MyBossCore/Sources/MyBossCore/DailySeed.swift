import Foundation

/// The daily challenge seed: every player in the world gets the same
/// campaign on the same UTC calendar day, so leaderboard scores compare.
public enum DailySeed {
    public static func seed(for date: Date = Date()) -> UInt64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let ymd = UInt64(parts.year! * 10_000 + parts.month! * 100 + parts.day!)
        // SplitMix64 finalizer so consecutive days land far apart.
        var z = ymd &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
