import Foundation

/// One exchange in a meeting duel: a provocation and the comebacks you can
/// throw back. One answer wins the round, everything else loses it.
public struct DuelRound: Codable, Equatable, Sendable {
    public let provocation: String
    public let comebacks: [String]
    public let correctIndex: Int

    public init(provocation: String, comebacks: [String], correctIndex: Int) {
        self.provocation = provocation
        self.comebacks = comebacks
        self.correctIndex = correctIndex
    }
}

/// A meeting duel: best of three rounds of corporate jargon versus wit.
/// Monkey Island insult sword-fighting, but the sword is a slide deck.
public struct Duel: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Who you are up against, e.g. "The Angry Client".
    public let opponent: String
    public let rounds: [DuelRound]
    public let winConsequence: Consequence
    public let loseConsequence: Consequence

    public init(
        id: String,
        opponent: String,
        rounds: [DuelRound],
        winConsequence: Consequence,
        loseConsequence: Consequence
    ) {
        self.id = id
        self.opponent = opponent
        self.rounds = rounds
        self.winConsequence = winConsequence
        self.loseConsequence = loseConsequence
    }
}

/// Tracks one best-of-three bout as the player answers round by round.
/// Ends early as soon as either side takes two rounds.
public struct DuelBout: Equatable, Sendable {
    public let duel: Duel
    public private(set) var wins = 0
    public private(set) var losses = 0
    private var nextRoundIndex = 0

    public init(duel: Duel) {
        self.duel = duel
    }

    public var isOver: Bool {
        wins == 2 || losses == 2 || nextRoundIndex >= duel.rounds.count
    }

    /// The round waiting for an answer — nil once the bout is over.
    public var currentRound: DuelRound? {
        isOver ? nil : duel.rounds[nextRoundIndex]
    }

    /// True once the bout is over and the player took more rounds.
    public var won: Bool? {
        isOver ? wins > losses : nil
    }

    /// Answers the current round; returns whether the comeback landed.
    @discardableResult
    public mutating func answer(comebackIndex: Int) -> Bool {
        guard let round = currentRound else { return false }
        let landed = comebackIndex == round.correctIndex
        if landed { wins += 1 } else { losses += 1 }
        nextRoundIndex += 1
        return landed
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

    /// The single climax duel against the Boss-AI (a lone object, not an array).
    public static func loadBoss() throws -> Duel {
        guard let url = Bundle.module.url(forResource: "boss", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Duel.self, from: Data(contentsOf: url))
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
