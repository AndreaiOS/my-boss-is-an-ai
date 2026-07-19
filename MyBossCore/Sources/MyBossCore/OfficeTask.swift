import Foundation

/// How the player resolves a task.
public enum WorkChoice: String, Codable, Sendable {
    case human
    case ai
}

/// A single office task the player must assign to Human or AI.
/// Content is data-driven: tasks are authored in JSON, not hardcoded.
public struct OfficeTask: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let humanConsequence: Consequence
    public let aiConsequence: Consequence
    /// Optional WarioWare micro-gag played when the player picks Human.
    /// The AI never plays: delegating means not playing.
    public let microGame: String?

    public init(
        id: String,
        title: String,
        humanConsequence: Consequence,
        aiConsequence: Consequence,
        microGame: String? = nil
    ) {
        self.id = id
        self.title = title
        self.humanConsequence = humanConsequence
        self.aiConsequence = aiConsequence
        self.microGame = microGame
    }

    public func consequence(for choice: WorkChoice) -> Consequence {
        switch choice {
        case .human: humanConsequence
        case .ai: aiConsequence
        }
    }
}
