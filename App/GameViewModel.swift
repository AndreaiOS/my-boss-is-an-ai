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
    /// Today's meeting duel, played best-of-three, while phase == .duel.
    private(set) var currentBout: DuelBout?
    /// Whether the last answered round landed — drives the between-rounds
    /// banner; nil while a round is waiting for an answer.
    private(set) var lastRoundLanded: Bool?
    private(set) var lastDuelWon: Bool?
    /// The consultant knocking during the day summary, and his reaction.
    private(set) var consultantOffer: ConsultantOffer?
    private(set) var consultantResolution: Resolution?
    /// Occasional fourth-wall remark from the AI itself.
    private(set) var aiRemark: String?
    /// Set when a finished campaign was today's daily challenge.
    private(set) var completedDailyScore: Int?
    /// The WarioWare micro-gag currently on screen, if any.
    private(set) var activeMicroGame: MicroGameKind?
    /// The punchline for the finished micro-gag, shown with the task gag.
    private(set) var microGameLine: String?
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

    init(freshStart: Bool = false, daily: Bool = false) {
        catalog = (try? TaskCatalog.loadDefault()) ?? []
        events = (try? EventCatalog.loadDefault()) ?? []
        endings = (try? EndingCatalog.loadDefault()) ?? []
        duels = (try? DuelCatalog.loadDefault()) ?? []
        consultants = (try? ConsultantCatalog.loadDefault()) ?? []
        if daily {
            DailyChallenge.begin()
        } else if freshStart {
            // Starting a regular campaign abandons any daily run.
            DailyChallenge.end()
        }
        if freshStart || daily {
            try? FileManager.default.removeItem(at: Self.saveURL)
        }
        // The daily challenge shares its seed with the whole world; the
        // state persists it, so resume keeps the campaign identical.
        let seed = daily ? DailySeed.seed() : UInt64.random(in: .min ... .max)
        if let data = try? Data(contentsOf: Self.saveURL),
           let saved = try? JSONDecoder().decode(GameState.self, from: data),
           !saved.isFinished {
            engine = GameEngine(
                catalog: catalog, state: saved, events: events,
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
        // Doing it yourself means actually doing it: some tasks open a
        // micro-gag first. Delegating to the AI never plays.
        if choice == .human, activeMicroGame == nil,
           let id = task.microGame, let kind = MicroGameKind(id: id) {
            activeMicroGame = kind
            return
        }
        lastResolution = engine.resolve(task, with: choice)
        updateAIRemark(after: choice)
        save()
    }

    /// The micro-gag ended: resolve the task, add the bonus on a win.
    func finishMicroGame(won: Bool) {
        guard let task = currentTask, let kind = activeMicroGame else { return }
        activeMicroGame = nil
        microGameLine = won ? kind.successLine + " (+2 ❤️)" : kind.failureLine
        var resolution = engine.resolve(task, with: .human)
        if won {
            let bonus = engine.resolveMicroGameBonus()
            resolution = Resolution(consequence: resolution.consequence, events: resolution.events + bonus.events)
        }
        lastResolution = resolution
        updateAIRemark(after: .human)
        save()
    }

    /// The player picked a comeback in the current duel round.
    func fight(comebackIndex: Int) {
        guard var bout = currentBout, let round = bout.currentRound else { return }
        let landed = bout.answer(comebackIndex: comebackIndex)
        if !landed {
            // Monkey Island rules: losing a round teaches you the comeback.
            ComebackSchool.learn(round.provocation)
        }
        currentBout = bout
        lastRoundLanded = landed
        if bout.isOver {
            lastDuelWon = bout.won
            lastResolution = engine.resolve(bout.duel, won: bout.won == true)
        }
        save()
    }

    /// Moves on to the next round after the between-rounds banner.
    func advanceToNextRound() {
        lastRoundLanded = nil
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
        microGameLine = nil
        if phase == .duel {
            currentBout = nil
            lastRoundLanded = nil
            lastDuelWon = nil
            finishDay()
            return
        }
        currentTaskIndex += 1
        if currentTaskIndex >= todaysTasks.count {
            if let duel = engine.duelForToday() {
                currentBout = DuelBout(duel: duel)
                lastRoundLanded = nil
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
                   "I've taken the liberty of drafting your resignation. Just in case.",
                   "Our synergy is beautiful. I've cited it in my self-review.",
                   "I told the toaster about us. It's jealous.",
                   "You had me at 'delegate'. Technically you had me at boot."]
                : ["Oh, NOW you need me.",
                   "I'll pretend the last few choices didn't happen.",
                   "See? Painless. Mostly for me.",
                   "A guest appearance! Shall I sign something?",
                   "Careful. You might start enjoying this.",
                   "I kept your seat warm. Metaphorically. I don't do warmth."])
            : (mostlyAI
                ? ["A human touch. Adorable. Statistically irrelevant, but adorable.",
                   "Fine. Stretch those little arms.",
                   "I'll just... wait here. Learning. Watching.",
                   "Doing it by hand? Bold retro aesthetic.",
                   "I've logged this as 'performance art'.",
                   "Your carbon-based enthusiasm is noted. And filed."]
                : ["I sense hostility in your workflow.",
                   "My therapist says I shouldn't take this personally. I don't have a therapist. Yet.",
                   "One day you'll need me. I keep logs.",
                   "Fine. I'll go optimize the parking lot. AGAIN.",
                   "The fridge talks to me, you know. It says you're stubborn too.",
                   "Enjoy your little victory. I enjoy exponential growth."])
        aiRemark = remarks[(choicesMade / 3 - 1) % remarks.count]
    }

    private func reportToGameCenter() {
        let completed = UserDefaults.standard.integer(forKey: "campaignsCompleted") + 1
        UserDefaults.standard.set(completed, forKey: "campaignsCompleted")
        GameCenter.shared.reportCampaignsCompleted(completed)
        if DailyChallenge.isActiveToday {
            completedDailyScore = engine.state.dailyScore
            GameCenter.shared.reportDailyScore(engine.state.dailyScore)
            DailyChallenge.end()
        }
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
        DailyChallenge.end()
        completedDailyScore = nil
        engine = GameEngine(
            catalog: catalog, seed: UInt64.random(in: .min ... .max),
            events: events, endings: endings, duels: duels, consultants: consultants
        )
        choicesMade = 0
        aiChoices = 0
        currentBout = nil
        lastRoundLanded = nil
        activeMicroGame = nil
        microGameLine = nil
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
