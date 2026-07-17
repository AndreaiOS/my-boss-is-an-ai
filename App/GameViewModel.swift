import Foundation
import MyBossCore

/// Drives the daily loop for the UI. All game rules live in MyBossCore;
/// this only sequences presentation and persists the save file.
@MainActor
@Observable
final class GameViewModel {

    enum Phase {
        case workday
        case duel
        case daySummary
        case campaignOver
    }

    private var engine: GameEngine
    private let catalog: [OfficeTask]
    private let events: [OfficeEvent]
    private let endings: [Ending]
    private let duels: [Duel]
    private let consultants: [ConsultantOffer]
    private(set) var todaysTasks: [OfficeTask] = []
    private(set) var currentTaskIndex = 0
    private(set) var phase: Phase = .workday
    /// The gag (and any office events) to show for the last resolved task,
    /// cleared on advance.
    private(set) var lastResolution: Resolution?
    /// Today's meeting duel, while phase == .duel.
    private(set) var currentDuel: Duel?
    private(set) var lastDuelWon: Bool?
    /// The consultant knocking during the day summary, and his reaction.
    private(set) var consultantOffer: ConsultantOffer?
    private(set) var consultantResolution: Resolution?
    /// Occasional fourth-wall remark from the AI itself.
    private(set) var aiRemark: String?
    private var choicesMade = 0
    private var aiChoices = 0

    private static let saveURL = URL.documentsDirectory.appending(path: "save.json")

    /// True when a saved campaign exists and is still in progress.
    static var hasResumableSave: Bool {
        guard let data = try? Data(contentsOf: saveURL),
              let saved = try? JSONDecoder().decode(GameState.self, from: data) else { return false }
        return !saved.isFinished
    }

    var day: Int { engine.state.day }
    var office: OfficeState { engine.state.office }
    var triggeredEventIDs: [String] { engine.state.triggeredEventIDs }
    var ending: Ending? { engine.finale() }
    var currentTask: OfficeTask? {
        guard phase == .workday, currentTaskIndex < todaysTasks.count else { return nil }
        return todaysTasks[currentTaskIndex]
    }

    init(freshStart: Bool = false) {
        catalog = (try? TaskCatalog.loadDefault()) ?? []
        events = (try? EventCatalog.loadDefault()) ?? []
        endings = (try? EndingCatalog.loadDefault()) ?? []
        duels = (try? DuelCatalog.loadDefault()) ?? []
        consultants = (try? ConsultantCatalog.loadDefault()) ?? []
        if freshStart {
            try? FileManager.default.removeItem(at: Self.saveURL)
        }
        let seed = UInt64.random(in: .min ... .max)
        if let data = try? Data(contentsOf: Self.saveURL),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           !saved.isFinished {
            engine = GameEngine(
                catalog: catalog, seed: seed, state: saved, events: events,
                endings: endings, duels: duels, consultants: consultants
            )
        } else {
            engine = GameEngine(
                catalog: catalog, seed: seed, events: events,
                endings: endings, duels: duels, consultants: consultants
            )
        }
        beginDay()
    }

    func choose(_ choice: WorkChoice) {
        guard let task = currentTask else { return }
        lastResolution = engine.resolve(task, with: choice)
        updateAIRemark(after: choice)
        save()
    }

    /// The player picked a comeback in today's meeting duel.
    func fight(comebackIndex: Int) {
        guard let duel = currentDuel else { return }
        lastDuelWon = comebackIndex == duel.correctIndex
        lastResolution = engine.resolve(duel, comebackIndex: comebackIndex)
        save()
    }

    /// The consultant got an answer during the day summary.
    func answerConsultant(accepted: Bool) {
        guard let offer = consultantOffer else { return }
        consultantResolution = engine.resolve(offer, accepted: accepted)
        save()
    }

    func advanceAfterConsequence() {
        lastResolution = nil
        aiRemark = nil
        if phase == .duel {
            currentDuel = nil
            lastDuelWon = nil
            finishDay()
            return
        }
        currentTaskIndex += 1
        if currentTaskIndex >= todaysTasks.count {
            if let duel = engine.duelForToday() {
                currentDuel = duel
                phase = .duel
            } else {
                finishDay()
            }
        }
    }

    private func finishDay() {
        engine.endDay()
        save()
        if engine.state.isFinished {
            phase = .campaignOver
            reportToGameCenter()
        } else {
            consultantOffer = engine.consultantForTonight()
            consultantResolution = nil
            phase = .daySummary
        }
    }

    /// Fourth-wall remarks: every third choice, the AI has opinions.
    private func updateAIRemark(after choice: WorkChoice) {
        choicesMade += 1
        if choice == .ai { aiChoices += 1 }
        guard choicesMade % 3 == 0 else {
            aiRemark = nil
            return
        }
        let mostlyAI = aiChoices * 2 >= choicesMade
        let remarks = choice == .ai
            ? (mostlyAI
                ? ["Excellent choice. As always. 🙂",
                   "Together we can automate anything. Even this conversation.",
                   "I've taken the liberty of drafting your resignation. Just in case."]
                : ["Oh, NOW you need me.",
                   "I'll pretend the last few choices didn't happen.",
                   "See? Painless. Mostly for me."])
            : (mostlyAI
                ? ["A human touch. Adorable. Statistically irrelevant, but adorable.",
                   "Fine. Stretch those little arms.",
                   "I'll just... wait here. Learning. Watching."]
                : ["I sense hostility in your workflow.",
                   "My therapist says I shouldn't take this personally. I don't have a therapist. Yet.",
                   "One day you'll need me. I keep logs."])
        aiRemark = remarks[(choicesMade / 3 - 1) % remarks.count]
    }

    private func reportToGameCenter() {
        let completed = UserDefaults.standard.integer(forKey: "campaignsCompleted") + 1
        UserDefaults.standard.set(completed, forKey: "campaignsCompleted")
        GameCenter.shared.reportCampaignsCompleted(completed)
        if let ending = engine.finale() {
            GameCenter.shared.reportEnding(ending.id)
            var found = Set(UserDefaults.standard.stringArray(forKey: "endingsFound") ?? [])
            found.insert(ending.id)
            UserDefaults.standard.set(Array(found).sorted(), forKey: "endingsFound")
        }
    }

    func startNextDay() {
        beginDay()
    }

    func restartCampaign() {
        try? FileManager.default.removeItem(at: Self.saveURL)
        engine = GameEngine(
            catalog: catalog, seed: UInt64.random(in: .min ... .max),
            events: events, endings: endings, duels: duels, consultants: consultants
        )
        choicesMade = 0
        aiChoices = 0
        currentDuel = nil
        consultantOffer = nil
        consultantResolution = nil
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
