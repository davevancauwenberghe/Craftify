//
//  CraftifyUITests.swift
//  CraftifyUITests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Testing
import XCTest
@testable import Craftify

struct CraftifyUITests {
    @MainActor
    @Test func testTextSizePickerInContentView() throws {
        // Launch the app
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to App Appearance (assumes "More" tab in ContentView)
        #expect(app.tabBars.buttons["More"].exists, "More tab should exist")
        app.tabBars.buttons["More"].tap()
        
        // Navigate to App Appearance view
        #expect(app.tables.cells.staticTexts["App Appearance"].exists, "App Appearance cell should exist")
        app.tables.cells.staticTexts["App Appearance"].tap()
        
        // Enable Custom Text Size toggle
        #expect(app.tables.cells.switches["Custom Text Size"].exists, "Custom Text Size toggle should exist")
        app.tables.cells.switches["Custom Text Size"].tap()
        
        // Verify scroll picker appears
        #expect(app.pickers["Text Size Picker"].exists, "Text Size Picker should be visible")
        
        // Select Extra Large
        app.pickers["Text Size Picker"].pickerWheels.element.adjust(toPickerWheelValue: "Extra Large")
        #expect(app.pickers["Text Size Picker"].pickerWheels.element.value as? String == "Extra Large", "Picker should select Extra Large")
    }
}
