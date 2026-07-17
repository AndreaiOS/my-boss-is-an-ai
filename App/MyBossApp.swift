import SwiftUI

@main
struct MyBossApp: App {
    init() {
        #if DEBUG
        // Verification hooks for UI tests: inject a save to showcase any
        // combination of day/scores/events, and keep the Game Center
        // sign-in sheet from covering screenshots.
        let env = ProcessInfo.processInfo.environment
        if let seeded = env["SEEDSAVE"], !seeded.isEmpty {
            try? seeded.data(using: .utf8)?
                .write(to: URL.documentsDirectory.appending(path: "save.json"))
        }
        if env["UITEST"] == "1" {
            UserDefaults.standard.set(true, forKey: "gcPromptShown")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
