import Foundation

/// One option in a story beat: a labelled choice with its own gag and score
/// consequence.
public struct StoryChoice: Codable, Equatable, Sendable {
    public let label: String
    public let flavorText: String
    public let consequence: Consequence

    public init(label: String, flavorText: String, consequence: Consequence) {
        self.label = label
        self.flavorText = flavorText
        self.consequence = consequence
    }
}

/// An authored narrative beat (e.g. the mid-campaign turn). The skeleton is
/// fixed; the narration adapts to the player's lean.
public struct StoryBeat: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let narration: [String: String]
    public let choices: [StoryChoice]

    public init(id: String, title: String, narration: [String: String], choices: [StoryChoice]) {
        self.id = id
        self.title = title
        self.narration = narration
        self.choices = choices
    }

    public func narration(for lean: Lean) -> String {
        narration[lean.rawValue] ?? narration["balanced"] ?? ""
    }
}

public enum StoryBeatCatalog {
    public static func decode(from data: Data) throws -> [StoryBeat] {
        try JSONDecoder().decode([StoryBeat].self, from: data)
    }

    public static func loadDefault() throws -> [StoryBeat] {
        guard let url = Bundle.module.url(forResource: "story", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
