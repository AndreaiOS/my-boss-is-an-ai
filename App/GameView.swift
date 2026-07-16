import SwiftUI
import SpriteKit
import MyBossCore

struct GameView: View {
    @State private var model = GameViewModel()
    @State private var scene = OfficeScene()

    var body: some View {
        VStack(spacing: 0) {
            header
            officeView
            Spacer()
            content
            Spacer()
        }
        .onAppear { syncScene() }
        .onChange(of: model.office.stage) { syncScene() }
        .onChange(of: model.triggeredEventIDs) { syncScene() }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .daySummary: SoundPlayer.shared.play(.dayEnd)
            case .campaignOver: SoundPlayer.shared.play(.ending)
            case .workday: break
            }
        }
    }

    private func resolveCurrentTask(with choice: WorkChoice) {
        model.choose(choice)
        SoundPlayer.shared.play(choice == .human ? .human : .ai)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scene.react()
        if let events = model.lastResolution?.events, !events.isEmpty {
            // Comebacks (they require something to undo) get the sparkle;
            // everything else gets the dramatic sting.
            let isComeback = events.contains { !$0.requiresAny.isEmpty }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SoundPlayer.shared.play(isComeback ? .eventGood : .eventBad)
                scene.shake()
                UINotificationFeedbackGenerator().notificationOccurred(isComeback ? .success : .warning)
            }
        }
    }

    private func syncScene() {
        scene.update(stage: model.office.stage, eventIDs: model.triggeredEventIDs)
    }

    private var header: some View {
        HStack {
            Text("Day \(model.day)")
                .font(.title2.bold())
            Spacer()
            Label("\(model.office.automation)", systemImage: "cpu")
            Label("\(model.office.humanity)", systemImage: "heart.fill")
        }
        .padding()
    }

    private var officeView: some View {
        SpriteView(scene: scene)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .workday:
            if let resolution = model.lastResolution {
                consequenceCard(resolution)
            } else if let task = model.currentTask {
                taskCard(task)
            }
        case .daySummary:
            daySummary
        case .campaignOver:
            campaignOver
        }
    }

    private func taskCard(_ task: OfficeTask) -> some View {
        VStack(spacing: 20) {
            Text("Task \(model.currentTaskIndex + 1) of \(model.todaysTasks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(task.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                choiceButton("🙋 Do it myself", tint: .orange) { resolveCurrentTask(with: .human) }
                choiceButton("🤖 Let AI do it", tint: .indigo) { resolveCurrentTask(with: .ai) }
            }
        }
        .padding()
    }

    private func choiceButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }

    private func consequenceCard(_ resolution: Resolution) -> some View {
        VStack(spacing: 16) {
            Text(resolution.consequence.flavorText)
                .font(.body.italic())
                .multilineTextAlignment(.center)
            ForEach(resolution.events) { event in
                Text(event.flavorText)
                    .font(.callout.bold())
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }
            Button("Next") {
                SoundPlayer.shared.play(.tap)
                model.advanceAfterConsequence()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var daySummary: some View {
        VStack(spacing: 16) {
            Text("Day \(model.day - 1) is over 🌙")
                .font(.title3.bold())
            Text(stageBlurb)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start next day") {
                SoundPlayer.shared.play(.tap)
                model.startNextDay()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var campaignOver: some View {
        VStack(spacing: 16) {
            if let ending = model.ending {
                Text(ending.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                ScrollView {
                    Text(ending.flavorText)
                        .font(.body.italic())
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: 220)
            } else {
                Text("The campaign is over!")
                    .font(.title2.bold())
                Text(stageBlurb)
                    .multilineTextAlignment(.center)
            }
            Button("Play again") {
                SoundPlayer.shared.play(.tap)
                model.restartCampaign()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var stageBlurb: String {
        switch model.office.stage {
        case .lively: "The office is messy, loud, and wonderfully human."
        case .hybrid: "Humans and robots share the coffee machine. It's… complicated."
        case .automated: "The office hums with perfect efficiency. Nobody laughs at the memes anymore."
        }
    }
}
