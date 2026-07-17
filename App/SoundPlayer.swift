import AVFoundation

/// Plays the synthesized 8-bit gags. Preloads every effect and uses the
/// ambient session category so the player's own music keeps playing.
@MainActor
final class SoundPlayer {

    enum Effect: String, CaseIterable {
        case human = "sfx_human"
        case ai = "sfx_ai"
        case eventBad = "sfx_event_bad"
        case eventGood = "sfx_event_good"
        case dayEnd = "sfx_day_end"
        case ending = "sfx_ending"
        case tap = "sfx_tap"
    }

    static let shared = SoundPlayer()

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[effect] = player
        }
    }

    func play(_ effect: Effect) {
        guard Settings.soundOn else { return }
        let player = players[effect]
        player?.currentTime = 0
        player?.play()
    }
}
