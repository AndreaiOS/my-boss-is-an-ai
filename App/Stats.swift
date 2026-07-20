import Foundation

/// Lifetime counters shown in the notebook. Thin wrapper over UserDefaults.
enum Stats: String, CaseIterable {
    case campaignsCompleted
    case duelsWonTotal
    case microGamesWon

    static func increment(_ stat: Stats, by amount: Int = 1) {
        UserDefaults.standard.set(value(stat) + amount, forKey: stat.rawValue)
    }

    static func value(_ stat: Stats) -> Int {
        UserDefaults.standard.integer(forKey: stat.rawValue)
    }
}
