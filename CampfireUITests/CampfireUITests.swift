import XCTest

final class CampfireUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCanFinishWithoutOptionalPermissions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-onboarding"]
        app.launch()

        let primaryButton = app.buttons["onboarding.primaryButton"]
        let expectedTitles = [
            "Start my fire",
            "Continue",
            "Got it",
            "Continue",
            "Continue",
            "Go to Campfire"
        ]

        for title in expectedTitles {
            XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
            XCTAssertEqual(primaryButton.label, title)
            primaryButton.tap()
        }

        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["home.screen"].exists || app.scrollViews["home.screen"].exists)
    }

    @MainActor
    func testSettingsExposesPrivacyAndSupportLinks() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-home"]
        app.launch()

        let settingsTab = app.buttons["tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let privacyLink = app.descendants(matching: .any)["settings.privacyPolicyLink"]
        let supportLink = app.descendants(matching: .any)["settings.supportLink"]

        for _ in 0..<6 where !privacyLink.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(privacyLink.waitForExistence(timeout: 3))
        XCTAssertTrue(privacyLink.isHittable)
        XCTAssertTrue(supportLink.exists)
        XCTAssertTrue(supportLink.isHittable)
    }
}
