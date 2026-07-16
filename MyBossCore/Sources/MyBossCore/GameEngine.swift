import Foundation

/// Full campaign state. Codable so it can be saved locally as-is.
public struct GameState: Codable, Equatable, Sendable {
    public var day: Int
    public var campaignLength: Int
    public var office: OfficeState
    /// IDs of office events that already fired; they never repeat.
    public var triggeredEventIDs: [String]

    public var isFinished: Bool { day > campaignLength }

    public init(campaignLength: Int) {
        day = 1
        self.campaignLength = campaignLength
        office = OfficeState()
        triggeredEventIDs = []
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
    private var rng: SeededRandomNumberGenerator

    public init(catalog: [OfficeTask], seed: UInt64, campaignLength: Int = 7, events: [OfficeEvent] = []) {
        self.catalog = catalog
        self.events = events
        rng = SeededRandomNumberGenerator(seed: seed)
        state = GameState(campaignLength: campaignLength)
    }

    /// Resumes a campaign from a previously saved state.
    public init(catalog: [OfficeTask], seed: UInt64, state: GameState, events: [OfficeEvent] = []) {
        self.catalog = catalog
        self.events = events
        rng = SeededRandomNumberGenerator(seed: seed)
        self.state = state
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
        let consequence = task.consequence(for: choice)
        state.office.apply(consequence)
        let fired = events.filter { event in
            !state.triggeredEventIDs.contains(event.id) && event.isTriggered(by: state.office)
        }
        state.triggeredEventIDs.append(contentsOf: fired.map(\.id))
        return Resolution(consequence: consequence, events: fired)
    }

    public func endDay() {
        state.day += 1
    }
}
