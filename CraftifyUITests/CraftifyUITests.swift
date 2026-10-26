import XCTest

@MainActor
final class CraftifyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(accessibilityText: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-hasLaunchedBefore", "YES", "-hasSeenChestsTutorial", "YES",
            "-isCraftifyPicksExpanded", "NO", "-colorSchemePreference", "system"
        ]
        if accessibilityText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func tab(_ title: String, in app: XCUIApplication) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func recipe(_ id: Int, in app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any).matching(identifier: "recipe-\(id)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            if row.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        return row
    }

    private func screenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAppearanceControlsAreReachableFromMore() {
        let app = launch()
        tab("More", in: app)
        let appearance = app.staticTexts["App Appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            if appearance.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        appearance.tap()
        screenshot("Appearance - Controls", app: app)
        let picker = app.segmentedControls["appearance-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Dark"].tap()
        XCTAssertTrue(picker.buttons["Dark"].isSelected)
        screenshot("Appearance - Dark", app: app)
    }

    func testRecipeAndIngredientNavigationSurviveRotation() {
        let app = launch()
        screenshot("Recipe Library", app: app)
        recipe(1, in: app).tap()
        XCTAssertTrue(app.buttons["add-to-chest"].waitForExistence(timeout: 5))
        screenshot("Crafting Table Layout", app: app)

        let ingredient = app.buttons["Ingredient: Oak Planks"].firstMatch
        XCTAssertTrue(ingredient.waitForExistence(timeout: 5))
        ingredient.tap()
        let subRecipe = app.buttons["View Oak Planks Recipe"]
        XCTAssertTrue(subRecipe.waitForExistence(timeout: 5))
        screenshot("Ingredient Details", app: app)
        subRecipe.tap()
        let output = app.buttons["Output: Oak Planks, quantity 4"].firstMatch
        XCTAssertTrue(output.waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        // Duo's display shape and system bars need not share the device's axis.
        let rotated = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in XCUIDevice.shared.orientation == .landscapeLeft }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        XCTAssertTrue(output.waitForExistence(timeout: 5))
        screenshot("Recipe - Landscape", app: app)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(output.waitForExistence(timeout: 5))
    }

    func testAlternateIngredientSearchRetainsQueryWhenOpeningRecipe() {
        let app = launch()
        tab("Search", in: app)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("spruce")
        let result = recipe(2, in: app)
        screenshot("Search - Alternate Ingredient", app: app)
        result.tap()
        XCTAssertTrue(app.buttons["add-to-chest"].waitForExistence(timeout: 5))
        if !field.isHittable {
            let back = app.descendants(matching: .any).matching(identifier: "BackButton").firstMatch
            if back.exists {
                back.tap()
            } else {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "spruce")
        XCTAssertTrue(recipe(2, in: app).exists)
    }

    func testRecipeCanBeStoredInAnExistingChest() {
        let app = launch()
        recipe(2, in: app).tap()
        app.buttons["add-to-chest"].tap()
        let chest = app.buttons["chest-choice-Starter Build"]
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        chest.tap()
        XCTAssertTrue(chest.waitForNonExistence(timeout: 5))
        tab("Chests", in: app)
        screenshot("Saved Chests", app: app)
        XCTAssertTrue(app.staticTexts["2 of 27 slots"].waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsRecipesAndChestControlsReachable() {
        let app = launch(accessibilityText: true)
        recipe(1, in: app).tap()
        XCTAssertTrue(app.buttons["add-to-chest"].waitForExistence(timeout: 5))
        screenshot("Recipe - Accessibility Text", app: app)
        app.buttons["add-to-chest"].tap()
        XCTAssertTrue(app.buttons["Create New Chest"].waitForExistence(timeout: 5))
        app.buttons["Create New Chest"].tap()
        let name = app.textFields["Chest name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Accessible Chest")
        screenshot("Chest Editor - Accessibility Text", app: app)
        app.buttons["Save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
    }

    func testFirstLaunchTourCanFinish() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-hasLaunchedBefore", "NO", "-hasSeenChestsTutorial", "YES"]
        app.launch()
        let start = app.buttons["Start Crafting"]
        for _ in 0..<10 {
            if start.exists { break }
            let next = app.buttons["Continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        screenshot("First Launch Tour", app: app)
        start.tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5))
        XCTAssertTrue(recipe(1, in: app).exists)
    }
}
