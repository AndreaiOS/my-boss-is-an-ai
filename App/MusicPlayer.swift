import AVFoundation
import MyBossCore

/// Maps an office stage to its background loop resource.
func MusicTrack(for stage: OfficeStage) -> String {
    switch stage {
    case .lively: "music_lively"
    case .hybrid: "music_hybrid"
    case .automated: "music_automated"
    }
}

/// Looping background music that crossfades between per-stage tracks. Respects
/// the player's music toggle; uses the ambient category so it ducks politely.
@MainActor
final class MusicPlayer {
    static let shared = MusicPlayer()

    /// Kept low so the music stays a background bed under the sound gags.
    private static let activeVolume: Float = 0.28

    private var players: [String: AVAudioPlayer] = [:]
    private var current: String?

    private init() {
        for name in ["music_lively", "music_hybrid", "music_automated"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0
            player?.prepareToPlay()
            players[name] = player
        }
    }

    func setStage(_ stage: OfficeStage) {
        guard Settings.musicOn else { stop(); return }
        let track = MusicTrack(for: stage)
        guard track != current else { return }
        current = track
        for (name, player) in players {
            if name == track {
                if !player.isPlaying { player.currentTime = 0; player.play() }
                player.setVolume(Self.activeVolume, fadeDuration: 1.0)
            } else {
                player.setVolume(0, fadeDuration: 1.0)
            }
        }
    }

    func stop() {
        current = nil
        for player in players.values { player.setVolume(0, fadeDuration: 0.4) }
    }
}
