import Foundation

/// Loads authored task content. Tasks live in JSON so designers (or future
/// you) can add jokes without touching code.
public enum TaskCatalog {

    public static func decode(from data: Data) throws -> [OfficeTask] {
        try JSONDecoder().decode([OfficeTask].self, from: data)
    }

    /// Loads the default catalog bundled with the package.
    public static func loadDefault() throws -> [OfficeTask] {
        guard let url = Bundle.module.url(forResource: "tasks", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
