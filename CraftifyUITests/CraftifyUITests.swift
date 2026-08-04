//
//  CraftifyUITests.swift
//  CraftifyUITests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import XCTest

final class CraftifyUITests: XCTestCase {
    @MainActor
    func testTextSizePickerInContentView() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launch()

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(
            moreTab.waitForExistence(timeout: 5),
            "More tab should exist"
        )
        moreTab.tap()

        let appearanceCell = app.tables.cells.staticTexts["App Appearance"]
        XCTAssertTrue(
            appearanceCell.waitForExistence(timeout: 5),
            "App Appearance cell should exist"
        )
        appearanceCell.tap()

        let textSizeToggle = app.tables.cells.switches["Custom Text Size"]
        XCTAssertTrue(
            textSizeToggle.waitForExistence(timeout: 5),
            "Custom Text Size toggle should exist"
        )
        textSizeToggle.tap()

        let textSizePicker = app.pickers["Text Size Picker"]
        XCTAssertTrue(
            textSizePicker.waitForExistence(timeout: 5),
            "Text Size Picker should be visible"
        )

        let pickerWheel = textSizePicker.pickerWheels.element
        pickerWheel.adjust(toPickerWheelValue: "Extra Large")
        XCTAssertEqual(
            pickerWheel.value as? String,
            "Extra Large",
            "Picker should select Extra Large"
        )
    }
}
