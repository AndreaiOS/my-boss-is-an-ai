import Foundation

/// Full campaign state. Codable so it can be saved locally as-is.
public struct GameState: Codable, Equatable, Sendable {
    public var day: Int
    public var campaignLength: Int
    public var office: OfficeState
    /// IDs of office events that already fired; they never repeat.
    public var triggeredEventIDs: [String]
    /// Meeting duels won this campaign — feeds the daily challenge score.
    /// Absent in v1.0 saves, so it decodes with a default.
    public var duelsWon: Int

    public var isFinished: Bool { day > campaignLength }

    /// Daily challenge score: staying human matters most, winning duels helps.
    public var dailyScore: Int { office.humanity * 2 + 25 * duelsWon }

    public init(campaignLength: Int) {
        day = 1
        self.campaignLength = campaignLength
        office = OfficeState()
        triggeredEventIDs = []
        duelsWon = 0
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        campaignLength = try container.decode(Int.self, forKey: .campaignLength)
        office = try container.decode(OfficeState.self, forKey: .office)
        triggeredEventIDs = try container.decode([String].self, forKey: .triggeredEventIDs)
        duelsWon = try container.decodeIfPresent(Int.self, forKey: .duelsWon) ?? 0
    }
}

/// What happened when a task was resolved: the immediate gag plus any
/// persistent office events its score change triggered.
public struct Resolution: Equatable, Sendable {
    public let consequence: Consequence
    public let events: [OfficeEvent]
}

/// Deterministic RNG (SplitMix64) so workdays are reproducible in tests
/// and replays. `SystemRandomNumberGenerator` is not seedable.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Drives the daily loop: deal tasks, resolve choices, evolve the office.
public final class GameEngine {
    public private(set) var state: GameState
    private let catalog: [OfficeTask]
    private let events: [OfficeEvent]
    private let endings: [Ending]
    private let duels: [Duel]
    private let consultants: [ConsultantOffer]
    private var rng: SeededRandomNumberGenerator

    public init(
        catalog: [OfficeTask],
        seed: UInt64,
        campaignLength: Int = 7,
        events: [OfficeEvent] = [],
        endings: [Ending] = [],
        duels: [Duel] = [],
        consultants: [ConsultantOffer] = []
    ) {
        self.catalog = catalog
        self.events = events
        self.endings = endings
        self.duels = duels
        self.consultants = consultants
        rng = SeededRandomNumberGenerator(seed: seed)
        state = GameState(campaignLength: campaignLength)
    }

    /// Resumes a campaign from a previously saved state.
    public init(
        catalog: [OfficeTask],
        seed: UInt64,
        state: GameState,
        events: [OfficeEvent] = [],
        endings: [Ending] = [],
        duels: [Duel] = [],
        consultants: [ConsultantOffer] = []
    ) {
        self.catalog = catalog
        self.events = events
        self.endings = endings
        self.duels = duels
        self.consultants = consultants
        rng = SeededRandomNumberGenerator(seed: seed)
        self.state = state
    }

    /// The campaign's ending — nil while days remain. First match in
    /// catalog order wins.
    public func finale() -> Ending? {
        guard state.isFinished else { return nil }
        return endings.first { $0.matches(state.office) }
    }

    /// Deals 3–5 unique tasks for today's workday.
    public func startDay() -> [OfficeTask] {
        let count = Int.random(in: 3...5, using: &rng)
        return Array(catalog.shuffled(using: &rng).prefix(count))
    }

    /// Applies the choice's consequence to the office and returns it —
    /// together with any newly triggered office events — so the
    /// presentation layer can show everything immediately.
    public func resolve(_ task: OfficeTask, with choice: WorkChoice) -> Resolution {
        apply(task.consequence(for: choice))
    }

    /// The meeting duel scheduled for today, if any: even days from day 2,
    /// rotating through the catalog.
    public func duelForToday() -> Duel? {
        guard !duels.isEmpty, state.day >= 2, state.day % 2 == 0 else { return nil }
        return duels[(state.day / 2 - 1) % duels.count]
    }

    public func resolve(_ duel: Duel, won: Bool) -> Resolution {
        if won { state.duelsWon += 1 }
        return apply(won ? duel.winConsequence : duel.loseConsequence)
    }

    /// The consultant knocking before tonight's summary: odd days from
    /// day 3, rotating through the catalog.
    public func consultantForTonight() -> ConsultantOffer? {
        guard !consultants.isEmpty, state.day >= 3, state.day % 2 == 1 else { return nil }
        return consultants[((state.day - 3) / 2) % consultants.count]
    }

    public func resolve(_ offer: ConsultantOffer, accepted: Bool) -> Resolution {
        apply(accepted ? offer.acceptConsequence : offer.refuseConsequence)
    }

    private func apply(_ consequence: Consequence) -> Resolution {
        state.office.apply(consequence)
        let fired = events.filter { event in
            !state.triggeredEventIDs.contains(event.id)
                && event.isTriggered(by: state.office)
                && (event.requiresAny.isEmpty
                    || event.requiresAny.contains(where: state.triggeredEventIDs.contains))
        }
        let undone = Set(fired.flatMap(\.undoes))
        state.triggeredEventIDs.removeAll(where: undone.contains)
        state.triggeredEventIDs.append(contentsOf: fired.map(\.id))
        return Resolution(consequence: consequence, events: fired)
    }

    public func endDay() {
        state.day += 1
    }
}
