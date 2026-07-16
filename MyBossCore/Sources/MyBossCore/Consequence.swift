import Foundation

/// The immediate, visible result of resolving a task with a Human or AI choice.
public struct Consequence: Codable, Equatable, Sendable {
    /// Stable identifier the presentation layer maps to a visual/sound gag.
    public let eventID: String
    /// The joke shown to the player.
    public let flavorText: String
    /// How much this pushes the office toward automation (can be negative).
    public let automationDelta: Int
    /// How much this affects the office's human warmth (can be negative).
    public let humanityDelta: Int

    public init(eventID: String, flavorText: String, automationDelta: Int, humanityDelta: Int) {
        self.eventID = eventID
        self.flavorText = flavorText
        self.automationDelta = automationDelta
        self.humanityDelta = humanityDelta
    }
}
