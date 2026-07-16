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
    private let events: [OfficeEvent]
    private let endings: [Ending]
    private(set) var todaysTasks: [OfficeTask] = []
    private(set) var currentTaskIndex = 0
    private(set) var phase: Phase = .workday
    /// The gag (and any office events) to show for the last resolved task,
    /// cleared on advance.
    private(set) var lastResolution: Resolution?

    private static let saveURL = URL.documentsDirectory.appending(path: "save.json")

    var day: Int { engine.state.day }
    var office: OfficeState { engine.state.office }
    var triggeredEventIDs: [String] { engine.state.triggeredEventIDs }
    var ending: Ending? { engine.finale() }
    var currentTask: OfficeTask? {
        guard phase == .workday, currentTaskIndex < todaysTasks.count else { return nil }
        return todaysTasks[currentTaskIndex]
    }

    init() {
        catalog = (try? TaskCatalog.loadDefault()) ?? []
        events = (try? EventCatalog.loadDefault()) ?? []
        endings = (try? EndingCatalog.loadDefault()) ?? []
        let seed = UInt64.random(in: .min ... .max)
        if let data = try? Data(contentsOf: Self.saveURL),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           !saved.isFinished {
            engine = GameEngine(catalog: catalog, seed: seed, state: saved, events: events, endings: endings)
        } else {
            engine = GameEngine(catalog: catalog, seed: seed, events: events, endings: endings)
        }
        beginDay()
    }

    func choose(_ choice: WorkChoice) {
        guard let task = currentTask else { return }
        lastResolution = engine.resolve(task, with: choice)
        save()
    }

    func advanceAfterConsequence() {
        lastResolution = nil
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
        engine = GameEngine(catalog: catalog, seed: UInt64.random(in: .min ... .max), events: events, endings: endings)
        beginDay()
    }

    private func beginDay() {
        todaysTasks = engine.startDay()
        currentTaskIndex = 0
        lastResolution = nil
        phase = .workday
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engine.state) {
            try? data.write(to: Self.saveURL, options: .atomic)
        }
    }
}
