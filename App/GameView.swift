import SwiftUI
import SpriteKit
import MyBossCore

struct GameView: View {
    @State private var model = GameViewModel()
    @State private var scene = OfficeScene()
    /// Big "DAY N" stamp shown when a new day starts.
    @State private var dayStamp: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Pixel.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    SpriteView(scene: scene)
                        .frame(height: geo.size.height * 0.56)
                        .clipped()
                    hud
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .top)

                if model.phase == .daySummary {
                    daySummaryOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if model.phase == .campaignOver {
                    endingOverlay
                        .transition(.opacity)
                }
                if let day = dayStamp {
                    dayStampView(day)
                        .transition(.scale(scale: 2.4).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.45), value: model.phase)
        }
        .onAppear {
            syncScene()
            showDayStamp(model.day)
        }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .workday:
                break
            case .daySummary:
                // The office transforms behind the summary overlay, so the
                // change is revealed the next morning.
                syncScene()
                SoundPlayer.shared.play(.dayEnd)
            case .campaignOver:
                syncScene()
                SoundPlayer.shared.play(.ending)
            }
        }
    }

    private func syncScene() {
        scene.update(stage: model.office.stage, eventIDs: model.triggeredEventIDs)
    }

    private func showDayStamp(_ day: Int) {
        withAnimation(.spring(duration: 0.4)) { dayStamp = day }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.3)) { dayStamp = nil }
        }
    }

    private func resolveCurrentTask(with choice: WorkChoice) {
        model.choose(choice)
        SoundPlayer.shared.play(choice == .human ? .human : .ai)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scene.react()
        if let events = model.lastResolution?.events, !events.isEmpty {
            let isComeback = events.contains { !$0.requiresAny.isEmpty }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SoundPlayer.shared.play(isComeback ? .eventGood : .eventBad)
                scene.shake()
                UINotificationFeedbackGenerator().notificationOccurred(isComeback ? .success : .warning)
            }
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                Text("DAY \(model.day)")
                    .font(Pixel.font(20))
                    .foregroundStyle(Pixel.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Pixel.panel)
                    .border(Pixel.border, width: 3)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    PixelMeter(icon: "🤖", value: model.office.automation, color: Pixel.ai)
                    PixelMeter(icon: "❤️", value: model.office.humanity, color: Pixel.bad)
                }
            }

            if let resolution = model.lastResolution {
                dialog(header: "WHAT HAPPENED", text: resolution.consequence.flavorText)
                ForEach(resolution.events) { event in
                    Text(event.flavorText)
                        .font(Pixel.font(12))
                        .foregroundStyle(.black.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Pixel.human.opacity(0.9))
                        .border(Pixel.border, width: 3)
                }
                Spacer(minLength: 0)
                Button("Next ▸") { SoundPlayer.shared.play(.tap); model.advanceAfterConsequence() }
                    .buttonStyle(PixelButtonStyle(color: Pixel.cream))
            } else if let task = model.currentTask {
                dialog(
                    header: "TASK \(model.currentTaskIndex + 1)/\(model.todaysTasks.count)",
                    text: task.title
                )
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    Button("🙋 Myself") { resolveCurrentTask(with: .human) }
                        .buttonStyle(PixelButtonStyle(color: Pixel.human))
                    Button("🤖 The AI") { resolveCurrentTask(with: .ai) }
                        .buttonStyle(PixelButtonStyle(color: Pixel.ai))
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .padding(.bottom, 6)
        .background(Pixel.panelDeep)
        .overlay(alignment: .top) { Rectangle().fill(Pixel.border).frame(height: 3) }
    }

    private func dialog(header: String, text: String) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(header)
                    .font(Pixel.font(11))
                    .foregroundStyle(Pixel.creamDim)
                Text(text)
                    .font(Pixel.font(16))
                    .foregroundStyle(Pixel.cream)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    // MARK: - Overlays

    private var daySummaryOverlay: some View {
        overlayCard {
            Text("🌙")
                .font(.system(size: 44))
            Text("DAY \(model.day - 1) COMPLETE")
                .font(Pixel.font(22))
                .foregroundStyle(Pixel.cream)
            Text(stageBlurb)
                .font(Pixel.font(13))
                .foregroundStyle(Pixel.creamDim)
                .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                PixelMeter(icon: "🤖", value: model.office.automation, color: Pixel.ai)
                PixelMeter(icon: "❤️", value: model.office.humanity, color: Pixel.bad)
            }
            Button("Start day \(model.day) ▸") {
                SoundPlayer.shared.play(.tap)
                model.startNextDay()
                showDayStamp(model.day)
            }
            .buttonStyle(PixelButtonStyle(color: Pixel.human))
        }
    }

    private var endingOverlay: some View {
        overlayCard {
            Text("🏆")
                .font(.system(size: 44))
            Text("THE END")
                .font(Pixel.font(13))
                .foregroundStyle(Pixel.creamDim)
            if let ending = model.ending {
                Text(ending.title.uppercased())
                    .font(Pixel.font(20))
                    .foregroundStyle(Pixel.cream)
                    .multilineTextAlignment(.center)
                ScrollView {
                    Text(ending.flavorText)
                        .font(Pixel.font(13))
                        .foregroundStyle(Pixel.cream.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: 190)
            }
            Button("Play again ▸") {
                SoundPlayer.shared.play(.tap)
                model.restartCampaign()
                syncScene()
                showDayStamp(1)
            }
            .buttonStyle(PixelButtonStyle(color: Pixel.human))
        }
    }

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Pixel.bg.opacity(0.88).ignoresSafeArea()
            PixelPanel {
                VStack(spacing: 16) { content() }
                    .padding(22)
            }
            .padding(.horizontal, 28)
        }
    }

    private func dayStampView(_ day: Int) -> some View {
        Text("DAY \(day)")
            .font(Pixel.font(46))
            .foregroundStyle(Pixel.cream)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Pixel.panel)
            .border(Pixel.border, width: 4)
            .background(Pixel.border.offset(x: 0, y: 6))
            .allowsHitTesting(false)
    }

    private var stageBlurb: String {
        switch model.office.stage {
        case .lively: "The office is messy, loud, and wonderfully human."
        case .hybrid: "Humans and robots share the coffee machine. It's… complicated."
        case .automated: "The office hums with perfect efficiency. Nobody laughs at the memes anymore."
        }
    }
}
