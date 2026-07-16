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

    public init(id: String, flavorText: String, metric: Metric, threshold: Int, direction: Direction) {
        self.id = id
        self.flavorText = flavorText
        self.metric = metric
        self.threshold = threshold
        self.direction = direction
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
