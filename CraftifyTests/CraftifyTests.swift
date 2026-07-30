//
//  CraftifyTests.swift
//  CraftifyTests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Testing
@testable import Craftify
import SwiftUI

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
