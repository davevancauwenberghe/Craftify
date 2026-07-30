//
//  CraftifyTests.swift
//  CraftifyTests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Testing
@testable import Craftify
import SwiftUI

private final class InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func array(forKey defaultName: String) -> [Any]? {
        values[defaultName] as? [Any]
    }

    func synchronize() -> Bool { true }
}

struct CraftifyTests {
    @MainActor
    @Test func testBackgroundICloudNotificationDoesNotViolateMainActorIsolation() async {
        let dataManager = DataManager()

        await Task.detached {
            NotificationCenter.default.post(
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default
            )
        }.value

        // Give the notification handler's main-actor task an opportunity to run.
        await Task.yield()
        #expect(dataManager.recentSearchNames.count <= 10)
    }

    @MainActor
    @Test func testDynamicTypeSettings() throws {
        // Create a test environment with AppStorage mock
        let userDefaults = UserDefaults(suiteName: "testCraftify")!
        userDefaults.removePersistentDomain(forName: "testCraftify")
        
        // Initialize AppAppearanceView
        let view = AppAppearanceView()
        
        // Set and verify toggle state
        userDefaults.set(true, forKey: "useCustomDynamicType")
        #expect(userDefaults.bool(forKey: "useCustomDynamicType") == true, "Custom Text Size toggle should be enabled")
        
        // Set and verify DynamicTypeSize
        userDefaults.set("xLarge", forKey: "customDynamicTypeSize")
        #expect(userDefaults.string(forKey: "customDynamicTypeSize") == "xLarge", "Custom DynamicTypeSize should be xLarge")
        
        // Simulate changing DynamicTypeSize
        userDefaults.set("accessibility1", forKey: "customDynamicTypeSize")
        #expect(userDefaults.string(forKey: "customDynamicTypeSize") == "accessibility1", "DynamicTypeSize should update to accessibility1")
        
        // Clean up
        userDefaults.removePersistentDomain(forName: "testCraftify")
    }

    @MainActor
    @Test func clearingSavedRecipesRemovesChestsAndLegacyFavorites() {
        let store = InMemoryKeyValueStore()
        let dataManager = DataManager(keyValueStore: store)
        store.set([1, 2, 3], forKey: "favoriteRecipes")
        dataManager.createChest(name: "Test Chest", size: .small)

        dataManager.clearChestsAndLegacyFavorites()

        #expect(dataManager.chests.isEmpty)
        #expect(store.array(forKey: "favoriteRecipes")?.isEmpty == true)
        #expect(store.object(forKey: "recipeChests.v1") == nil)
    }

    @MainActor
    @Test func recentSearchHistorySynchronizesThroughUbiquitousStore() {
        let store = InMemoryKeyValueStore()
        let firstDevice = DataManager(keyValueStore: store)
        let secondDevice = DataManager(keyValueStore: store)
        let recipe = Recipe(
            id: 1,
            name: "Crafting Table",
            image: "Crafting Table",
            ingredients: ["Oak Planks"],
            alternateIngredients: nil,
            alternateIngredients1: nil,
            alternateIngredients2: nil,
            alternateIngredients3: nil,
            output: 1,
            alternateOutput: nil,
            alternateOutput1: nil,
            alternateOutput2: nil,
            alternateOutput3: nil,
            category: "Utility",
            imageremark: nil,
            remarks: nil
        )
        firstDevice.recipes = [recipe]
        secondDevice.recipes = [recipe]

        firstDevice.saveRecentSearch(recipe)
        secondDevice.syncRecentSearches()

        #expect(secondDevice.recentSearchNames == [recipe.name])
    }
}

extension CraftifyTests {
    @Test func chestSizesMatchJavaEditionAndEnforceCapacity() throws {
        #expect(RecipeChest.Size.small.rawValue == 27)
        #expect(RecipeChest.Size.large.rawValue == 54)

        let overflowingIDs = Array(0...60)
        let chest = RecipeChest(name: "Build ideas", size: .large, recipeIDs: overflowingIDs)
        #expect(chest.recipeIDs.count == 54)

        let encoded = try JSONEncoder().encode(chest)
        let decoded = try JSONDecoder().decode(RecipeChest.self, from: encoded)
        #expect(decoded == chest)
    }
}
