import Foundation

/// The strings shown on a shareable end-of-campaign card. Pure and testable;
/// the SwiftUI card and the image renderer live in the app layer.
public struct ShareCardContent: Equatable, Sendable {
    public let title: String
    public let tagline: String
    public let scoreLine: String
    public let footer: String

    public init(ending: Ending, office: OfficeState, dailyScore: Int? = nil) {
        title = ending.title.uppercased()
        tagline = Self.trim(ending.flavorText, to: 90)
        var line = "🤖 \(office.automation)  ❤️ \(office.humanity)"
        if let dailyScore { line += "  ☀️ \(dailyScore)" }
        scoreLine = line
        footer = "My Boss Is an AI"
    }

    static func trim(_ text: String, to max: Int) -> String {
        guard text.count > max else { return text }
        let slice = text.prefix(max)
        if let space = slice.lastIndex(of: " ") {
            return String(slice[..<space]) + "…"
        }
        return String(slice) + "…"
    }
}
