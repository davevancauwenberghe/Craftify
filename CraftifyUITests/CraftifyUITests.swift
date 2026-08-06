//
//  CraftifyUITests.swift
//  CraftifyUITests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import XCTest

final class CraftifyUITests: XCTestCase {
    @MainActor
    func testAppearanceControlsAreReachableFromMore() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launch()

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(
            moreTab.waitForExistence(timeout: 5),
            "More tab should exist"
        )
        moreTab.tap()

        let appearanceCell = app.staticTexts["App Appearance"]
        XCTAssertTrue(
            appearanceCell.waitForExistence(timeout: 5),
            "App Appearance destination should exist"
        )
        appearanceCell.tap()

        let appearancePicker = app.segmentedControls["Appearance"]
        XCTAssertTrue(
            appearancePicker.waitForExistence(timeout: 5),
            "Appearance picker should exist"
        )

        let darkAppearance = appearancePicker.buttons["Dark"]
        XCTAssertTrue(
            darkAppearance.exists,
            "Dark appearance option should exist"
        )
        darkAppearance.tap()
        XCTAssertTrue(darkAppearance.isSelected)
    }
}
