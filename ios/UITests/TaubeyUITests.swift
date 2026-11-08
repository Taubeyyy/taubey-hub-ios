import XCTest

/// Taps through the app in the simulator with the sample data (`-uitest`) and
/// photographs every screen into SHOT_DIR, which the CI uploads as an artifact.
final class TaubeyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System questions") { alert in
            for label in ["Erlauben", "Allow", "Zulassen", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    func testTour() {
        app.launchArguments += ["-uitest"]
        app.launch()
        sleep(3)
        app.swipeUp()       // lets the monitor answer the notification question
        app.swipeDown()
        sleep(2)
        shot("01-uebersicht")
        app.swipeUp()
        sleep(1)
        shot("02-uebersicht-mitte")
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        shot("03-uebersicht-unten")

        // one account
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        let alt = app.buttons["Alt"].firstMatch
        if alt.waitForExistence(timeout: 3) {
            alt.tap()
            sleep(2)
            shot("04-uebersicht-alt")
            let all = app.buttons["Alle"].firstMatch
            if all.exists { all.tap() }
        }

        tab("Instanzen")
        sleep(1)
        shot("05-instanzen")
        let main = app.staticTexts["Taubeyyyy"].firstMatch
        if main.waitForExistence(timeout: 3) {
            main.tap()
            sleep(2)
            shot("06-instanz")
            app.swipeUp()
            sleep(1)
            shot("07-instanz-unten")
            let edit = app.buttons["Script-Einstellungen bearbeiten"].firstMatch
            if edit.waitForExistence(timeout: 3) {
                edit.tap()
                sleep(2)
                shot("08-einstellungen")
                let bag = app.buttons["Bag"].firstMatch
                if bag.waitForExistence(timeout: 3) {
                    bag.tap()
                    sleep(1)
                    shot("09-einstellungen-bag")
                }
                app.navigationBars.buttons.element(boundBy: 0).tap()
                sleep(1)
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }
        let all = app.staticTexts["Einstellungen für alle"].firstMatch
        if all.waitForExistence(timeout: 3) {
            all.tap()
            sleep(2)
            shot("10-standard")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tab("Inventar")
        sleep(2)
        shot("11-inventar")
        tab("Events")
        sleep(2)
        shot("12-events")
        tab("Konto")
        sleep(1)
        shot("13-konto")
        app.swipeUp()
        sleep(1)
        shot("14-konto-unten")
    }

    func testSignIn() {
        app.launchArguments += ["-uitest-signedout"]
        app.launch()
        sleep(2)
        shot("00-anmelden")
    }

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "tab \(name) missing")
        button.tap()
    }

    private func shot(_ name: String) {
        let image = app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? image.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
        }
    }
}
