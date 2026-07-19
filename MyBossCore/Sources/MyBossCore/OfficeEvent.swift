import Foundation

/// A persistent office transformation (layoff, robot arrival, sentient
/// coffee machine…). Fires once when a score crosses its threshold and is
/// remembered in the save so it never repeats.
public struct OfficeEvent: Codable, Equatable, Sendable, Identifiable {

    public enum Metric: String, Codable, Sendable {
        case automation
        case humanity
    }

    public enum Direction: String, Codable, Sendable {
        case above
        case below
    }

    public let id: String
    /// The announcement shown to the player.
    public let flavorText: String
    public let metric: Metric
    public let threshold: Int
    public let direction: Direction
    /// Events this one reverses: their IDs (and scene props) are removed
    /// when this fires, so they can fire again later — the world oscillates.
    public let undoes: [String]
    /// This event only fires while at least one of these events is active.
    /// Keeps comebacks from firing before there is anything to come back from.
    public let requiresAny: [String]
    /// Short comic onomatopoeia popped in the office scene when this fires.
    public let sting: String?

    public init(
        id: String,
        flavorText: String,
        metric: Metric,
        threshold: Int,
        direction: Direction,
        undoes: [String] = [],
        requiresAny: [String] = [],
        sting: String? = nil
    ) {
        self.id = id
        self.flavorText = flavorText
        self.metric = metric
        self.threshold = threshold
        self.direction = direction
        self.undoes = undoes
        self.requiresAny = requiresAny
        self.sting = sting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        flavorText = try container.decode(String.self, forKey: .flavorText)
        metric = try container.decode(Metric.self, forKey: .metric)
        threshold = try container.decode(Int.self, forKey: .threshold)
        direction = try container.decode(Direction.self, forKey: .direction)
        undoes = try container.decodeIfPresent([String].self, forKey: .undoes) ?? []
        requiresAny = try container.decodeIfPresent([String].self, forKey: .requiresAny) ?? []
        sting = try container.decodeIfPresent(String.self, forKey: .sting)
    }

    func isTriggered(by office: OfficeState) -> Bool {
        let value = switch metric {
        case .automation: office.automation
        case .humanity: office.humanity
        }
        return switch direction {
        case .above: value >= threshold
        case .below: value < threshold
        }
    }
}

/// Loads authored office events. Like tasks, events live in JSON.
public enum EventCatalog {

    public static func decode(from data: Data) throws -> [OfficeEvent] {
        try JSONDecoder().decode([OfficeEvent].self, from: data)
    }

    public static func loadDefault() throws -> [OfficeEvent] {
        guard let url = Bundle.module.url(forResource: "events", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
