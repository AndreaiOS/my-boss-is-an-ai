import SwiftUI
import MyBossCore

/// The full-screen turning-point interstitial that opens Act II. The narration
/// is picked by the player's lean; the two choices steer the second half.
struct StoryBeatView: View {
    let beat: StoryBeat
    let narration: String
    let onChoose: (StoryChoice) -> Void

    var body: some View {
        ZStack {
            Pixel.bg.opacity(0.94).ignoresSafeArea()
            PixelPanel {
                VStack(spacing: 18) {
                    Text("📣 \(beat.title)")
                        .font(Pixel.font(18))
                        .foregroundStyle(Pixel.bad)
                        .multilineTextAlignment(.center)
                    ScrollView {
                        Text(narration)
                            .font(Pixel.font(13))
                            .foregroundStyle(Pixel.cream)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 200)
                    ForEach(beat.choices.indices, id: \.self) { i in
                        Button(beat.choices[i].label) {
                            SoundPlayer.shared.play(.tap)
                            onChoose(beat.choices[i])
                        }
                        .buttonStyle(PixelButtonStyle(color: i == 0 ? Pixel.ai : Pixel.human))
                    }
                }
                .padding(22)
            }
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
    }
}
