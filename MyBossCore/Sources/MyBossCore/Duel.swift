import Foundation

/// A meeting duel: someone fires corporate jargon at you and you pick the
/// comeback. One answer wins, everything else loses. Monkey Island insult
/// sword-fighting, but the sword is a slide deck.
public struct Duel: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Who you are up against, e.g. "The Angry Client".
    public let opponent: String
    public let provocation: String
    public let comebacks: [String]
    public let correctIndex: Int
    public let winConsequence: Consequence
    public let loseConsequence: Consequence

    public init(
        id: String,
        opponent: String,
        provocation: String,
        comebacks: [String],
        correctIndex: Int,
        winConsequence: Consequence,
        loseConsequence: Consequence
    ) {
        self.id = id
        self.opponent = opponent
        self.provocation = provocation
        self.comebacks = comebacks
        self.correctIndex = correctIndex
        self.winConsequence = winConsequence
        self.loseConsequence = loseConsequence
    }
}

public enum DuelCatalog {
    public static func decode(from data: Data) throws -> [Duel] {
        try JSONDecoder().decode([Duel].self, from: data)
    }

    public static func loadDefault() throws -> [Duel] {
        guard let url = Bundle.module.url(forResource: "duels", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}

/// The consultant in the plaid suit who knocks between days, selling
/// automation packages nobody asked for.
public struct ConsultantOffer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pitch: String
    public let acceptConsequence: Consequence
    public let refuseConsequence: Consequence

    public init(
        id: String,
        pitch: String,
        acceptConsequence: Consequence,
        refuseConsequence: Consequence
    ) {
        self.id = id
        self.pitch = pitch
        self.acceptConsequence = acceptConsequence
        self.refuseConsequence = refuseConsequence
    }
}

public enum ConsultantCatalog {
    public static func decode(from data: Data) throws -> [ConsultantOffer] {
        try JSONDecoder().decode([ConsultantOffer].self, from: data)
    }

    public static func loadDefault() throws -> [ConsultantOffer] {
        guard let url = Bundle.module.url(forResource: "consultant", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
