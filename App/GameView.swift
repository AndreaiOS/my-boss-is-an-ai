import SwiftUI
import SpriteKit
import MyBossCore

struct GameView: View {
    let onExitToTitle: () -> Void
    @State private var model: GameViewModel
    @State private var scene = OfficeScene()
    /// Big "DAY N" stamp shown when a new day starts.
    @State private var dayStamp: Int?
    @State private var showPause = false

    init(freshStart: Bool = false, daily: Bool = false, onExitToTitle: @escaping () -> Void = {}) {
        self.onExitToTitle = onExitToTitle
        _model = State(initialValue: GameViewModel(freshStart: freshStart, daily: daily))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Pixel.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    SpriteView(scene: scene)
                        .frame(height: geo.size.height * 0.66)
                        .clipped()
                    hud
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .top)

                if let kind = model.activeMicroGame {
                    MicroGameOverlay(kind: kind) { won in finishMicroGame(won: won) }
                        .zIndex(2)
                }
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
            syncDaylight()
            showDayStamp(model.day)
        }
        .onChange(of: model.currentTaskIndex) { syncDaylight() }
        .sheet(isPresented: $showPause) {
            PauseSheet(
                onRestart: {
                    model.restartCampaign()
                    syncScene()
                    syncDaylight()
                    showDayStamp(1)
                },
                onExitToTitle: onExitToTitle
            )
        }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .workday, .duel:
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

    /// Morning light at the first task, sunset by the last.
    private func syncDaylight() {
        let total = max(model.todaysTasks.count - 1, 1)
        scene.setDaylight(progress: Double(min(model.currentTaskIndex, total)) / Double(total))
    }

    private func showDayStamp(_ day: Int) {
        withAnimation(.spring(duration: 0.4)) { dayStamp = day }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.3)) { dayStamp = nil }
        }
    }

    private func fightDuel(comebackIndex: Int) {
        model.fight(comebackIndex: comebackIndex)
        let landed = model.lastRoundLanded == true
        SoundPlayer.shared.play(landed ? .eventGood : .eventBad)
        Haptics.notify(landed ? .success : .error)
        scene.react(to: landed ? .human : .ai)
        scene.duelSting(won: landed)
        if landed { scene.emote(for: .human) } else { scene.shake() }
    }

    private func resolveCurrentTask(with choice: WorkChoice) {
        model.choose(choice)
        if model.activeMicroGame != nil {
            // A micro-gag opened instead: effects wait for its outcome.
            SoundPlayer.shared.play(.tap)
            return
        }
        playResolutionEffects(for: choice)
    }

    private func finishMicroGame(won: Bool) {
        withAnimation(.spring(duration: 0.3)) {
            model.finishMicroGame(won: won)
        }
        if won { scene.spawnComicText("🎯 CRIT!") }
        playResolutionEffects(for: .human)
    }

    private func playResolutionEffects(for choice: WorkChoice) {
        SoundPlayer.shared.play(choice == .human ? .human : .ai)
        Haptics.impact()
        scene.react(to: choice)
        scene.emote(for: choice)
        scene.taskSting(for: choice)
        celebrate(model.lastResolution?.events ?? [])
    }

    /// Shared fanfare when office events fire: shake, sound, comic sting.
    private func celebrate(_ events: [OfficeEvent]) {
        guard !events.isEmpty else { return }
        let isComeback = events.contains { !$0.requiresAny.isEmpty }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SoundPlayer.shared.play(isComeback ? .eventGood : .eventBad)
            scene.shake()
            Haptics.notify(isComeback ? .success : .warning)
            for (index, event) in events.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 * Double(index)) {
                    scene.sting(event.sting ?? "!", forEvent: event.id)
                    scene.reactToEvent(event.id)
                }
            }
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Text("DAY \(model.day)")
                    .font(Pixel.font(17))
                    .foregroundStyle(Pixel.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Pixel.panel)
                    .border(Pixel.border, width: 3)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    PixelMeter(icon: "🤖", value: model.office.automation, color: Pixel.ai)
                    PixelMeter(icon: "❤️", value: model.office.humanity, color: Pixel.bad)
                }
                Button {
                    SoundPlayer.shared.play(.tap)
                    showPause = true
                } label: {
                    Text("॥")
                        .font(Pixel.font(16))
                        .foregroundStyle(Pixel.cream)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Pixel.panel)
                        .border(Pixel.border, width: 3)
                }
            }

            if let resolution = model.lastResolution {
                // Long gags + event banners can outgrow the HUD: the
                // message area scrolls, the button stays pinned below.
                ScrollView {
                    VStack(spacing: 10) {
                        dialog(
                            header: model.phase == .duel
                                ? (model.lastDuelWon == true ? "DUEL WON 🏆" : "DUEL LOST 💥")
                                : "WHAT HAPPENED",
                            text: resolution.consequence.flavorText
                        )
                        ForEach(resolution.events) { event in
                            Text(event.flavorText)
                                .font(Pixel.font(12))
                                .foregroundStyle(.black.opacity(0.85))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Pixel.human.opacity(0.9))
                                .border(Pixel.border, width: 3)
                        }
                        if let line = model.microGameLine {
                            Text("🎮 \(line)")
                                .font(Pixel.font(11))
                                .foregroundStyle(Pixel.bad)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let remark = model.aiRemark {
                            Text("🤖 the AI: \(remark)")
                                .font(Pixel.font(11))
                                .foregroundStyle(Pixel.ai.opacity(0.95))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                Button("Next ▸") { SoundPlayer.shared.play(.tap); model.advanceAfterConsequence() }
                    .buttonStyle(PixelButtonStyle(color: Pixel.cream))
            } else if model.phase == .duel, let bout = model.currentBout {
                ScrollView {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(uiImage: UIImage(named: "angry_client") ?? UIImage())
                                .resizable()
                                .interpolation(.none)
                                .frame(width: 56, height: 56)
                            Text("⚔️ MEETING DUEL")
                                .font(Pixel.font(14))
                                .foregroundStyle(Pixel.bad)
                            Spacer()
                            Text("YOU \(bout.wins) — \(bout.losses) THEM")
                                .font(Pixel.font(11))
                                .foregroundStyle(Pixel.creamDim)
                        }
                        if let landed = model.lastRoundLanded {
                            // Between rounds: the blow landed (or didn't).
                            dialog(
                                header: landed ? "ROUND WON 🎯" : "ROUND LOST 😖",
                                text: landed
                                    ? "A direct hit. The room takes notes."
                                    : "That one stung. You will NOT fall for it again. (Learned ★)"
                            )
                        } else if let round = bout.currentRound {
                            dialog(
                                header: "\(bout.duel.opponent.uppercased()) · ROUND \(bout.wins + bout.losses + 1)/3",
                                text: "“\(round.provocation)”"
                            )
                            let learned = ComebackSchool.hasLearned(round.provocation)
                            ForEach(round.comebacks.indices, id: \.self) { index in
                                let star = learned && index == round.correctIndex ? "★ " : ""
                                Button(star + round.comebacks[index]) { fightDuel(comebackIndex: index) }
                                    .buttonStyle(PixelComebackButtonStyle())
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                if model.lastRoundLanded != nil {
                    Button("Next round ▸") {
                        SoundPlayer.shared.play(.tap)
                        model.advanceToNextRound()
                    }
                    .buttonStyle(PixelButtonStyle(color: Pixel.cream))
                }
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
        .padding(14)
        .padding(.bottom, 2)
        .background(Pixel.panelDeep)
        .overlay(alignment: .top) { Rectangle().fill(Pixel.border).frame(height: 3) }
    }

    private func dialog(header: String, text: String) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(header)
                    .font(Pixel.font(11))
                    .foregroundStyle(Pixel.creamDim)
                TypewriterText(text: text, font: Pixel.font(16), color: Pixel.cream)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    // MARK: - Overlays

    private var daySummaryOverlay: some View {
        overlayCard {
            if let offer = model.consultantOffer, model.consultantResolution == nil {
                // The consultant knocks before the night ends.
                Image(uiImage: UIImage(named: "consultant") ?? UIImage())
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 80, height: 80)
                Text("A KNOCK AT THE DOOR")
                    .font(Pixel.font(16))
                    .foregroundStyle(Pixel.cream)
                Text("“\(offer.pitch)”")
                    .font(Pixel.font(13))
                    .foregroundStyle(Pixel.cream.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button("Sign here 🖊") {
                    SoundPlayer.shared.play(.ai)
                    model.answerConsultant(accepted: true)
                    syncScene()
                }
                .buttonStyle(PixelButtonStyle(color: Pixel.ai))
                Button("Slam the door") {
                    SoundPlayer.shared.play(.human)
                    model.answerConsultant(accepted: false)
                    syncScene()
                }
                .buttonStyle(PixelButtonStyle(color: Pixel.human))
            } else {
                Text("🌙")
                    .font(.system(size: 44))
                Text("DAY \(model.day - 1) COMPLETE")
                    .font(Pixel.font(22))
                    .foregroundStyle(Pixel.cream)
                if let reaction = model.consultantResolution {
                    Text(reaction.consequence.flavorText)
                        .font(Pixel.font(12))
                        .foregroundStyle(Pixel.cream.opacity(0.9))
                        .multilineTextAlignment(.center)
                } else {
                    Text(stageBlurb)
                        .font(Pixel.font(13))
                        .foregroundStyle(Pixel.creamDim)
                        .multilineTextAlignment(.center)
                }
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
    }

    @MainActor
    private func shareEnding() {
        guard let ending = model.ending else { return }
        let content = ShareCardContent(ending: ending, office: model.office, dailyScore: model.completedDailyScore)
        let renderer = ImageRenderer(content: ShareCardView(content: content, artwork: EndingArt.image(for: ending)))
        renderer.scale = 1
        guard let image = renderer.uiImage else { return }
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?
            .present(activity, animated: true)
    }

    private var endingOverlay: some View {
        overlayCard {
            Text("THE END")
                .font(Pixel.font(13))
                .foregroundStyle(Pixel.creamDim)
            if let ending = model.ending {
                Image(uiImage: UIImage(named: EndingArt.image(for: ending)) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .border(Pixel.border, width: 3)
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
                .frame(maxHeight: 140)
            }
            if let score = model.completedDailyScore {
                Text("☀️ DAILY SCORE: \(score)")
                    .font(Pixel.font(15))
                    .foregroundStyle(Pixel.bad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .border(Pixel.bad, width: 3)
            }
            Button("Share ▸") { SoundPlayer.shared.play(.tap); shareEnding() }
                .buttonStyle(PixelButtonStyle(color: Pixel.ai))
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
