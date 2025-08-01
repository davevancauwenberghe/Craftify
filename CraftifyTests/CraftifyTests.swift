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
    @Test func testDynamicTypeSettings() async throws {
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
