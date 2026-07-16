import Foundation
import MyBossCore

/// Drives the daily loop for the UI. All game rules live in MyBossCore;
/// this only sequences presentation and persists the save file.
@MainActor
@Observable
final class GameViewModel {

    enum Phase {
        case workday
        case daySummary
        case campaignOver
    }

    private var engine: GameEngine
    private let catalog: [OfficeTask]
    private(set) var todaysTasks: [OfficeTask] = []
    private(set) var currentTaskIndex = 0
    private(set) var phase: Phase = .workday
    /// The gag to show for the last resolved task, cleared on advance.
    private(set) var lastConsequence: Consequence?

    private static let saveURL = URL.documentsDirectory.appending(path: "save.json")

    var day: Int { engine.state.day }
    var office: OfficeState { engine.state.office }
    var currentTask: OfficeTask? {
        guard phase == .workday, currentTaskIndex < todaysTasks.count else { return nil }
        return todaysTasks[currentTaskIndex]
    }

    init() {
        catalog = (try? TaskCatalog.loadDefault()) ?? []
        let seed = UInt64.random(in: .min ... .max)
        if let data = try? Data(contentsOf: Self.saveURL),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           !saved.isFinished {
            engine = GameEngine(catalog: catalog, seed: seed, state: saved)
        } else {
            engine = GameEngine(catalog: catalog, seed: seed)
        }
        beginDay()
    }

    func choose(_ choice: WorkChoice) {
        guard let task = currentTask else { return }
        lastConsequence = engine.resolve(task, with: choice)
        save()
    }

    func advanceAfterConsequence() {
        lastConsequence = nil
        currentTaskIndex += 1
        if currentTaskIndex >= todaysTasks.count {
            engine.endDay()
            save()
            phase = engine.state.isFinished ? .campaignOver : .daySummary
        }
    }

    func startNextDay() {
        beginDay()
    }

    func restartCampaign() {
        try? FileManager.default.removeItem(at: Self.saveURL)
        engine = GameEngine(catalog: catalog, seed: UInt64.random(in: .min ... .max))
        beginDay()
    }

    private func beginDay() {
        todaysTasks = engine.startDay()
        currentTaskIndex = 0
        lastConsequence = nil
        phase = .workday
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engine.state) {
            try? data.write(to: Self.saveURL, options: .atomic)
        }
    }
}
