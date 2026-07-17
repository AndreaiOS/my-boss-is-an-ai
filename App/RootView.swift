import SwiftUI

/// Switches between the title screen and a running game. Each entry into
/// the game gets a fresh view identity so New Game truly restarts.
struct RootView: View {

    private enum Screen: Equatable {
        case title
        case game(fresh: Bool, session: Int)
    }

    @State private var screen: Screen = .title
    @State private var session = 0

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleView(
                    onContinue: { enterGame(fresh: false) },
                    onNewGame: { enterGame(fresh: true) }
                )
            case .game(let fresh, let session):
                GameView(freshStart: fresh, onExitToTitle: { screen = .title })
                    .id(session)
            }
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            GameCenter.shared.authenticate()
            // Verification hook: jump straight into the game (e.g. to
            // screenshot a seeded save from the command line).
            if CommandLine.arguments.contains("-skipTitle")
                || ProcessInfo.processInfo.environment["SKIPTITLE"] == "1" {
                enterGame(fresh: false)
            }
        }
    }

    private func enterGame(fresh: Bool) {
        session += 1
        screen = .game(fresh: fresh, session: session)
    }
}
