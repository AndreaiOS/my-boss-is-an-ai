import Foundation

/// A campaign ending. Selected at the end of the last day: the first entry
/// in catalog order whose bounds all match the final office scores wins,
/// so specific endings go first and an unbounded fallback goes last.
public struct Ending: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let flavorText: String
    /// Inclusive bounds on the final scores; absent means unbounded.
    public let minAutomation: Int?
    public let maxAutomation: Int?
    public let minHumanity: Int?
    public let maxHumanity: Int?

    public init(
        id: String,
        title: String,
        flavorText: String,
        minAutomation: Int? = nil,
        maxAutomation: Int? = nil,
        minHumanity: Int? = nil,
        maxHumanity: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.flavorText = flavorText
        self.minAutomation = minAutomation
        self.maxAutomation = maxAutomation
        self.minHumanity = minHumanity
        self.maxHumanity = maxHumanity
    }

    public func matches(_ office: OfficeState) -> Bool {
        matches(automation: office.automation, humanity: office.humanity)
    }

    public func matches(automation: Int, humanity: Int) -> Bool {
        automation >= (minAutomation ?? Int.min)
            && automation <= (maxAutomation ?? Int.max)
            && humanity >= (minHumanity ?? Int.min)
            && humanity <= (maxHumanity ?? Int.max)
    }
}

/// Loads authored endings. Like tasks and events, endings live in JSON.
public enum EndingCatalog {

    public static func decode(from data: Data) throws -> [Ending] {
        try JSONDecoder().decode([Ending].self, from: data)
    }

    public static func loadDefault() throws -> [Ending] {
        guard let url = Bundle.module.url(forResource: "endings", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
