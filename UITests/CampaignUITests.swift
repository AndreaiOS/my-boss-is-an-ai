import XCTest

/// Plays a whole campaign end to end: tasks, meeting duels, the consultant,
/// day transitions, the ending screen and a restart. If any phase of the
/// loop dead-ends, this fails.
final class CampaignUITests: XCTestCase {

    func testFullCampaign() {
        let app = XCUIApplication()
        app.launch()

        // Title screen → fresh campaign.
        let newGame = app.buttons["NEW GAME"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        newGame.tap()

        let knownLabels: Set<String> = [
            "NEW GAME", "▸ CONTINUE", "OPTIONS", "॥",
            "🙋 MYSELF", "🤖 THE AI", "NEXT ▸", "PLAY AGAIN ▸",
            "SIGN HERE 🖊", "SLAM THE DOOR"
        ]
        var humanTurn = true

        for step in 0..<600 {
            if app.buttons["PLAY AGAIN ▸"].exists {
                // Campaign completed: restart once to prove the loop closes.
                app.buttons["PLAY AGAIN ▸"].tap()
                XCTAssertTrue(
                    app.buttons["🙋 MYSELF"].waitForExistence(timeout: 10)
                        || app.buttons["🤖 THE AI"].exists
                )
                return
            }
            if tap(app.buttons["NEXT ▸"]) { continue }
            if app.buttons["SIGN HERE 🖊"].exists {
                _ = tap(app.buttons[step % 2 == 0 ? "SIGN HERE 🖊" : "SLAM THE DOOR"])
                continue
            }
            if tapButton(matching: "START DAY", in: app) { continue }
            if app.buttons["🙋 MYSELF"].exists || app.buttons["🤖 THE AI"].exists {
                _ = tap(app.buttons[humanTurn ? "🙋 MYSELF" : "🤖 THE AI"])
                humanTurn.toggle()
                continue
            }
            // Meeting duel: the only remaining tappable buttons are comebacks.
            let comeback = app.buttons.allElementsBoundByIndex.first {
                $0.isHittable && !knownLabels.contains($0.label) && !$0.label.isEmpty
            }
            if let comeback, tap(comeback) { continue }
            // Nothing tappable right now (animation in flight): wait briefly.
            usleep(400_000)
        }
        XCTFail("Campaign did not reach the ending screen")
    }

    /// Continues the seeded save and idles so the scene can be
    /// screenshotted externally (used for placement verification).
    /// Idles on the title screen for external screenshots.
    func testTitleShowcase() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST"] = "1"
        if let seed = ProcessInfo.processInfo.environment["SEEDSAVE"], !seed.isEmpty {
            app.launchEnvironment["SEEDSAVE"] = seed
        }
        app.launch()
        XCTAssertTrue(app.buttons["NEW GAME"].waitForExistence(timeout: 10))
        sleep(25)
    }

    func testShowcase() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST"] = "1"
        if let seed = ProcessInfo.processInfo.environment["SEEDSAVE"], !seed.isEmpty {
            app.launchEnvironment["SEEDSAVE"] = seed
        }
        app.launch()
        let continueButton = app.buttons["▸ CONTINUE"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()
        XCTAssertTrue(app.buttons["🙋 MYSELF"].waitForExistence(timeout: 10))
        sleep(25)
    }

    private func tap(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        element.tap()
        return true
    }

    private func tapButton(matching prefix: String, in app: XCUIApplication) -> Bool {
        let button = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)
        ).firstMatch
        return tap(button)
    }
}
