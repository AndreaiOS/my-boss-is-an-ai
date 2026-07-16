import Foundation

/// The visible evolutionary stage of the office, driven by the automation score.
public enum OfficeStage: String, Codable, Sendable {
    case lively
    case hybrid
    case automated
}

/// Cumulative world state. Scores live in 0...100.
public struct OfficeState: Codable, Equatable, Sendable {
    public private(set) var automation: Int
    public private(set) var humanity: Int

    public init() {
        automation = 0
        humanity = 100
    }

    public var stage: OfficeStage {
        switch automation {
        case ..<40: .lively
        case ..<70: .hybrid
        default: .automated
        }
    }

    public mutating func apply(_ consequence: Consequence) {
        automation = min(100, max(0, automation + consequence.automationDelta))
        humanity = min(100, max(0, humanity + consequence.humanityDelta))
    }
}
