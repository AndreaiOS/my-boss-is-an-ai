/// The dramatic act a given campaign day belongs to (2–3–2 over 7 days).
public enum Act: Sendable, Equatable {
    case setup, escalation, climax

    public init(for day: Int) {
        switch day {
        case ..<3: self = .setup
        case 3...5: self = .escalation
        default: self = .climax
        }
    }
}

/// How the player has been leaning, read from the accumulated office scores —
/// the same signal that drives stages and endings, so no extra tracking.
public enum Lean: String, Sendable, Equatable {
    case human, ai, balanced

    public static func from(_ office: OfficeState) -> Lean {
        if office.automation >= 55 { return .ai }
        if office.humanity >= 60 && office.automation < 40 { return .human }
        return .balanced
    }
}
