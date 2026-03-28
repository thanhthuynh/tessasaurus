//
//  TessasaurusUITests.swift
//  TessasaurusUITests
//

import XCTest

final class TessasaurusUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Skip onboarding on clean simulator
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()
    }

    // MARK: - App Launch & Tab Navigation

    @MainActor
    func testAppLaunches() throws {
        let photosTab = app.buttons["Photos"]
        XCTAssertTrue(photosTab.waitForExistence(timeout: 5))
    }

    @MainActor
    func testTabBarShowsBothTabs() throws {
        let photosTab = app.buttons["Photos"]
        let couponsTab = app.buttons["Coupons"]

        XCTAssertTrue(photosTab.waitForExistence(timeout: 5))
        XCTAssertTrue(couponsTab.exists)
    }

    @MainActor
    func testSwitchToCouponsTab() throws {
        let couponsTab = app.buttons["Coupons"]
        XCTAssertTrue(couponsTab.waitForExistence(timeout: 5))
        couponsTab.tap()

        // Coupons screen shows "Tessa" name
        let name = app.staticTexts["Tessa"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwitchBackToPhotosTab() throws {
        let couponsTab = app.buttons["Coupons"]
        let photosTab = app.buttons["Photos"]

        XCTAssertTrue(couponsTab.waitForExistence(timeout: 5))
        couponsTab.tap()

        XCTAssertTrue(photosTab.waitForExistence(timeout: 3))
        photosTab.tap()

        let header = app.staticTexts["Our Memories"]
        XCTAssertTrue(header.waitForExistence(timeout: 3))
    }

    // MARK: - Photo Wall

    @MainActor
    func testPhotoWallShowsHeader() throws {
        let header = app.staticTexts["Our Memories"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPhotoWallShowsPhotoCount() throws {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'photos'")
        let photoCountLabel = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(photoCountLabel.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsMenuExists() throws {
        let settingsButton = app.buttons["Settings menu"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsMenuOpens() throws {
        let settingsButton = app.buttons["Settings menu"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // SwiftUI Menu items appear as buttons — wait for any "Switch to" or "Refresh"
        let refreshOption = app.buttons["Refresh"]
        XCTAssertTrue(refreshOption.waitForExistence(timeout: 5))
    }

    // MARK: - Add Photo Sheet (requires uploader mode)

    @MainActor
    func testAddPhotoButtonVisibleInUploaderMode() throws {
        switchToUploaderMode()

        let addButton = app.buttons["Add photos"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddPhotoSheetOpensAndDismisses() throws {
        switchToUploaderMode()

        let addButton = app.buttons["Add photos"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Sheet should show "Add Photos" nav title
        let navTitle = app.navigationBars["Add Photos"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Should show picker prompt
        let selectText = app.staticTexts["Select Photos"]
        XCTAssertTrue(selectText.waitForExistence(timeout: 3))

        // Cancel should dismiss
        app.buttons["Cancel"].tap()
        XCTAssertFalse(navTitle.waitForExistence(timeout: 3))
    }

    // MARK: - Coupons

    @MainActor
    func testCouponsScreenShowsNameAndCoupons() throws {
        app.buttons["Coupons"].tap()

        let name = app.staticTexts["Tessa"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))

        // Should show available count
        let predicate = NSPredicate(format: "label CONTAINS[c] 'available'")
        let availableLabel = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(availableLabel.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCouponCardExistsAndTappable() throws {
        app.buttons["Coupons"].tap()

        // Wait for coupons to appear — find by partial label match
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Kisses'")
        let couponCard = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(couponCard.waitForExistence(timeout: 5))

        // Tap to show redeem confirmation
        couponCard.tap()

        // Should show redeem button
        let redeemButton = app.buttons["Redeem"]
        XCTAssertTrue(redeemButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCouponRedeemCancelDismisses() throws {
        app.buttons["Coupons"].tap()

        let predicate = NSPredicate(format: "label CONTAINS[c] 'Kisses'")
        let couponCard = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(couponCard.waitForExistence(timeout: 5))
        couponCard.tap()

        let redeemButton = app.buttons["Redeem"]
        XCTAssertTrue(redeemButton.waitForExistence(timeout: 5))

        // Cancel should dismiss confirmation
        app.buttons["Cancel"].tap()

        // Redeem button should disappear
        XCTAssertTrue(redeemButton.waitForNonExistence(timeout: 3))
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let perfApp = XCUIApplication()
            perfApp.launchArguments += ["-hasCompletedOnboarding", "YES"]
            perfApp.launch()
        }
    }

    // MARK: - Helpers

    private func switchToUploaderMode() {
        let settingsButton = app.buttons["Settings menu"]
        guard settingsButton.waitForExistence(timeout: 5) else { return }
        settingsButton.tap()

        let switchToUploader = app.buttons["Switch to Uploader Mode"]
        if switchToUploader.waitForExistence(timeout: 3) {
            switchToUploader.tap()
        } else {
            // Already in uploader mode — dismiss menu
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
