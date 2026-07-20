/// One ending row in the notebook: found (revealed) or still locked.
public struct NotebookEnding: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let found: Bool

    public init(id: String, title: String, found: Bool) {
        self.id = id
        self.title = title
        self.found = found
    }
}

/// Builds the notebook's ending list: catalog order, each flagged found or
/// still locked. Presentation (thumbnails, silhouettes) is the app's job.
public enum NotebookContent {
    public static func endings(_ catalog: [Ending], found: Set<String>) -> [NotebookEnding] {
        catalog.map { NotebookEnding(id: $0.id, title: $0.title, found: found.contains($0.id)) }
    }
}
