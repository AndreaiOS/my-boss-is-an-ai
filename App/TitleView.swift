import SwiftUI
import SpriteKit
import MyBossCore

/// Title screen: the lively office plays behind the logo.
struct TitleView: View {
    let onContinue: () -> Void
    let onNewGame: () -> Void
    @State private var scene = OfficeScene()
    @State private var showOptions = false

    private var canContinue: Bool { GameViewModel.hasResumableSave }
    private var endingsFound: Int { UserDefaults.standard.stringArray(forKey: "endingsFound")?.count ?? 0 }
    private var endingsTotal: Int { (try? EndingCatalog.loadDefault())?.count ?? 7 }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Pixel.bg.opacity(0.9), .clear, Pixel.bg.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("MY BOSS")
                        .font(Pixel.font(44))
                    Text("IS AN AI")
                        .font(Pixel.font(44))
                        .foregroundStyle(Pixel.ai)
                    Text("a comedy about work, robots and one mug")
                        .font(Pixel.font(11))
                        .foregroundStyle(Pixel.cream)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Pixel.bg.opacity(0.75))
                        .padding(.top, 10)
                }
                .foregroundStyle(Pixel.cream)
                .shadow(color: Pixel.border, radius: 0, x: 0, y: 4)
                .padding(.top, 70)

                Spacer()

                VStack(spacing: 14) {
                    if canContinue {
                        Button("▸ Continue") { SoundPlayer.shared.play(.tap); onContinue() }
                            .buttonStyle(PixelButtonStyle(color: Pixel.human))
                    }
                    Button("New game") { SoundPlayer.shared.play(.tap); onNewGame() }
                        .buttonStyle(PixelButtonStyle(color: canContinue ? Pixel.cream : Pixel.human))
                    Button("Options") { SoundPlayer.shared.play(.tap); showOptions = true }
                        .buttonStyle(PixelButtonStyle(color: Pixel.ai))
                    if endingsFound > 0 {
                        Text("ENDINGS FOUND \(endingsFound)/\(endingsTotal)")
                            .font(Pixel.font(11))
                            .foregroundStyle(Pixel.cream)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Pixel.bg.opacity(0.75))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showOptions) { OptionsSheet() }
    }
}

/// In-game pause menu: options plus restart/exit.
struct PauseSheet: View {
    let onRestart: () -> Void
    let onExitToTitle: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sound = Settings.soundOn
    @State private var haptics = Settings.hapticsOn

    var body: some View {
        VStack(spacing: 16) {
            Text("PAUSED")
                .font(Pixel.font(18))
                .foregroundStyle(Pixel.cream)
            Toggle("Sound effects", isOn: $sound)
                .onChange(of: sound) { Settings.soundOn = sound }
            Toggle("Haptics", isOn: $haptics)
                .onChange(of: haptics) { Settings.hapticsOn = haptics }
            Button("Resume ▸") { dismiss() }
                .buttonStyle(PixelButtonStyle(color: Pixel.human))
            Button("Restart campaign") { dismiss(); onRestart() }
                .buttonStyle(PixelButtonStyle(color: Pixel.cream))
            Button("Back to title") { dismiss(); onExitToTitle() }
                .buttonStyle(PixelButtonStyle(color: Pixel.ai))
        }
        .font(Pixel.font(14))
        .foregroundStyle(Pixel.cream)
        .tint(Pixel.human)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Pixel.panelDeep)
        .presentationDetents([.height(400)])
    }
}

/// Sound & haptics toggles, shared by the title screen and the pause menu.
struct OptionsSheet: View {
    @State private var sound = Settings.soundOn
    @State private var haptics = Settings.hapticsOn

    var body: some View {
        VStack(spacing: 18) {
            Text("OPTIONS")
                .font(Pixel.font(18))
                .foregroundStyle(Pixel.cream)
            Toggle("Sound effects", isOn: $sound)
                .onChange(of: sound) { Settings.soundOn = sound }
            Toggle("Haptics", isOn: $haptics)
                .onChange(of: haptics) { Settings.hapticsOn = haptics }
            Text("Made by a human. Mostly.")
                .font(Pixel.font(10))
                .foregroundStyle(Pixel.creamDim)
        }
        .font(Pixel.font(14))
        .foregroundStyle(Pixel.cream)
        .tint(Pixel.human)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Pixel.panelDeep)
        .presentationDetents([.height(260)])
    }
}
