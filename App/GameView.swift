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
        .onAppear { scene.stage = model.office.stage }
        .onChange(of: model.office.stage) { scene.stage = model.office.stage }
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
            if let consequence = model.lastConsequence {
                consequenceCard(consequence)
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
                choiceButton("🙋 Do it myself", tint: .orange) { model.choose(.human) }
                choiceButton("🤖 Let AI do it", tint: .indigo) { model.choose(.ai) }
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

    private func consequenceCard(_ consequence: Consequence) -> some View {
        VStack(spacing: 16) {
            Text(consequence.flavorText)
                .font(.body.italic())
                .multilineTextAlignment(.center)
            Button("Next") { model.advanceAfterConsequence() }
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
            Button("Start next day") { model.startNextDay() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var campaignOver: some View {
        VStack(spacing: 16) {
            Text("The campaign is over!")
                .font(.title2.bold())
            Text(stageBlurb)
                .multilineTextAlignment(.center)
            Button("Play again") { model.restartCampaign() }
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
