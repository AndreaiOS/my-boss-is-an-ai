import SwiftUI

@main
struct MyBossApp: App {
    init() {
        #if DEBUG
        // Verification hook: UI tests can inject a save to showcase any
        // combination of day/scores/events before the title screen looks
        // for one.
        if let seeded = ProcessInfo.processInfo.environment["SEEDSAVE"],
           !seeded.isEmpty {
            try? seeded.data(using: .utf8)?
                .write(to: URL.documentsDirectory.appending(path: "save.json"))
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
