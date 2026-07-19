import GameKit

/// Thin Game Center wrapper. Everything fails silently when the player is
/// not authenticated or the IDs are not configured yet in App Store
/// Connect, so the game never depends on it.
@MainActor
final class GameCenter {

    static let shared = GameCenter()
    private(set) var isAuthenticated = false

    private init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController {
                // Ask once per install; never nag on every launch.
                guard !UserDefaults.standard.bool(forKey: "gcPromptShown") else { return }
                UserDefaults.standard.set(true, forKey: "gcPromptShown")
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                    .first?
                    .present(viewController, animated: true)
                return
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    /// One achievement per ending, ID `ending.<endingID>` in App Store Connect.
    func reportEnding(_ endingID: String) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: "ending.\(endingID)")
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    /// Leaderboard `campaigns_completed`: total finished campaigns.
    func reportCampaignsCompleted(_ total: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            total, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: ["campaigns_completed"]
        ) { _ in }
    }

    /// Leaderboard `daily_challenge`: today's shared-seed campaign score.
    func reportDailyScore(_ score: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: ["daily_challenge"]
        ) { _ in }
    }
}
