//
//  CraftifyTests.swift
//  CraftifyTests
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Testing
@testable import Craftify
import SwiftUI

private final class InMemoryKeyValueStore: NSObject, KeyValueStore, @unchecked Sendable {
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

@MainActor
private final class DataTestContext {
    let store = InMemoryKeyValueStore()
    let suiteName = "CraftifyTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let manager: DataManager

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        manager = DataManager(keyValueStore: store, defaults: defaults, startsServices: false)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }
}

struct CraftifyTests {
    @MainActor
    @Test func testBackgroundICloudNotificationDoesNotViolateMainActorIsolation() async {
        let context = DataTestContext()
        defer { context.cleanUp() }
        let store = context.store
        store.set(["Crafting Table"], forKey: "recentSearches")

        await Task.detached {
            NotificationCenter.default.post(
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store
            )
        }.value
        for _ in 0..<10 { await Task.yield() }
        #expect(context.manager.recentSearchNames == ["Crafting Table"])
    }

    @MainActor
    @Test func clearingSavedRecipesPropagatesToOtherDevices() throws {
        let context = DataTestContext()
        defer { context.cleanUp() }
        let second = DataManager(keyValueStore: context.store, defaults: context.defaults, startsServices: false)
        context.store.set([1, 2, 3], forKey: "favoriteRecipes")
        context.manager.createChest(name: "Test Chest", size: .small)
        second.syncChests()
        #expect(second.chests.count == 1)

        context.manager.clearChestsAndLegacyFavorites()
        second.syncChests()

        #expect(context.manager.chests.isEmpty)
        #expect(second.chests.isEmpty)
        #expect(context.store.array(forKey: "favoriteRecipes")?.isEmpty == true)
        let data = try #require(context.store.data(forKey: "recipeChests.v1"))
        #expect(try JSONDecoder().decode([RecipeChest].self, from: data).isEmpty)
    }

    @MainActor
    @Test func recentSearchHistorySynchronizesThroughUbiquitousStore() {
        let context = DataTestContext()
        defer { context.cleanUp() }
        let firstDevice = context.manager
        let secondDevice = DataManager(keyValueStore: context.store, defaults: context.defaults, startsServices: false)
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
    @Test func searchIncludesEveryAlternateAndRespectsScope() {
        let recipe = Recipe(
            id: 901, name: "Crème Block", image: "Stone", ingredients: ["Oak Planks"],
            alternateIngredients: ["Spruce Planks"], alternateIngredients1: ["Birch Planks"],
            alternateIngredients2: ["Cherry Planks"], alternateIngredients3: ["Bamboo Planks"],
            output: 1, alternateOutput: nil, alternateOutput1: nil,
            alternateOutput2: nil, alternateOutput3: nil,
            category: "Building", imageremark: nil, remarks: nil
        )
        for ingredient in ["Oak", "Spruce", "Birch", "Cherry", "Bamboo"] {
            #expect(recipe.matchesSearch("  \(ingredient.uppercased())  ", scope: .ingredients))
            #expect(!recipe.matchesSearch(ingredient, scope: .names))
        }
        #expect(recipe.matchesSearch("creme", scope: .names))
        #expect(!recipe.matchesSearch("creme", scope: .ingredients))
        #expect(recipe.matchesSearch(" \n "))
    }

    @Test func craftingOptionsPreserveGapsAndOutputPairing() {
        let recipe = Recipe(
            id: 902, name: "Test", image: "Stone", ingredients: ["Stone"],
            alternateIngredients: ["", " "], alternateIngredients1: ["Spruce Planks"],
            alternateIngredients2: nil, alternateIngredients3: ["Oak Planks"],
            output: 1, alternateOutput: 99, alternateOutput1: 4,
            alternateOutput2: nil, alternateOutput3: nil,
            category: "Test", imageremark: nil, remarks: nil
        )
        #expect(recipe.craftingOptions.map(\.output) == [1, 4, 1])
        #expect(recipe.craftingOptions.map { $0.ingredients.count } == [9, 9, 9])
        #expect(recipe.craftingOptions[1].ingredients[0] == "Spruce Planks")
    }

    @MainActor
    @Test func chestsAndHistorySurviveUnavailableICloudAndAnEmptyLibrary() {
        let context = DataTestContext()
        defer { context.cleanUp() }
        let recipe = announcementRecipe(id: 1, name: "Crafting Table")
        context.manager.createChest(name: "Offline Build", size: .small, adding: recipe)
        context.manager.saveRecentSearch(recipe)

        let reopened = DataManager(
            keyValueStore: InMemoryKeyValueStore(), defaults: context.defaults, startsServices: false
        )
        #expect(reopened.recipes.isEmpty)
        #expect(reopened.chests.first?.recipeIDs == [1])
        #expect(reopened.recentSearchNames == [recipe.name])
    }

    @MainActor
    @Test func legacyFavoritesMigrateWithoutLosingRecipesOrRepeatingMigration() {
        let context = DataTestContext()
        defer { context.cleanUp() }
        context.store.set(Array(1...70), forKey: "favoriteRecipes")
        context.manager.syncChests()
        #expect(context.manager.chests.count == 2)
        #expect(context.manager.chests.flatMap(\.recipeIDs) == Array(1...70))
        context.manager.syncChests()
        #expect(context.manager.chests.count == 2)
        context.manager.clearChestsAndLegacyFavorites()
        context.manager.syncChests()
        #expect(context.manager.chests.isEmpty)
    }

    @Test func decodedChestsDeduplicateAndEnforceCapacity() throws {
        let chest = RecipeChest(name: "Test", size: .small)
        let data = try JSONEncoder().encode(chest)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["recipeIDs"] = [1, 1, 2] + Array(3...60)
        let malformed = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(RecipeChest.self, from: malformed)
        #expect(decoded.recipeIDs == Array(1...27))
    }

    @MainActor
    @Test func reportFetchOnCooldownReturnsThePreviousReports() {
        let context = DataTestContext()
        defer { context.cleanUp() }
        let report = RecipeReport(
            id: "test", recordID: "test", localID: "test", reportType: "Recipe error",
            recipeName: "Crafting Table", category: "Utility", recipeID: 1,
            description: "Test report", timestamp: Date(), status: "Pending"
        )
        context.manager.cacheRecipeReports([report])
        var returnedIDs: [String] = []
        context.manager.fetchRecipeReports { result in
            if case .success(let reports) = result { returnedIDs = reports.map(\.id) }
        }
        #expect(returnedIDs == [report.id])
    }

    @MainActor
    @Test func syncStatusDoesNotHideErrorsBehindTheLastSuccess() {
        let context = DataTestContext()
        defer { context.cleanUp() }
        context.manager.lastUpdated = Date()
        context.manager.errorMessage = "Try again"
        #expect(context.manager.syncStatus == "Sync failed: Try again")
        context.manager.isLoading = true
        #expect(context.manager.syncStatus == "Syncing recipes...")
    }

    @MainActor
    @Test func hingeColumnsLeaveTheEntireReservedRegionEmpty() throws {
        let columns = try #require(CraftifyLayout.dividedColumns(
            width: 900, division: CGRect(x: 420, y: 0, width: 60, height: 700),
            minimum: 156, spacing: 16, dynamicTypeSize: .large
        ))
        #expect(columns.count == 4)
        #expect(columns[1].spacing == 60)
        if case .fixed(let width) = columns[0].size { #expect(width == 202) }
        else { Issue.record("Expected a fixed column before the hinge") }
        if case .fixed(let width) = columns[2].size { #expect(width == 202) }
        else { Issue.record("Expected a fixed column after the hinge") }
        let accessible = try #require(CraftifyLayout.dividedColumns(
            width: 900, division: CGRect(x: 420, y: 0, width: 60, height: 700),
            minimum: 156, spacing: 16, dynamicTypeSize: .accessibility5
        ))
        #expect(accessible.count == 2)
        #expect(accessible[0].spacing == 60)
    }

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


extension CraftifyTests {
    @Test func imageAssetRecordNamesAreStableAndCloudKitSafe() {
        #expect(
            CraftImageAssetKey.recordName(for: "Oak Planks")
                == "asset-T2FrIFBsYW5rcw"
        )
        #expect(
            CraftImageAssetKey.recordName(for: "Oak Planks")
                != CraftImageAssetKey.recordName(for: "Oak Log")
        )
    }

    @MainActor
    @Test func recipeImageKeysIncludeOutputsAlternatesAndRemarks() {
        let recipe = Recipe(
            id: 42,
            name: "Test Recipe",
            image: "Output",
            ingredients: ["Ingredient", ""],
            alternateIngredients: ["Alternate"],
            alternateIngredients1: nil,
            alternateIngredients2: nil,
            alternateIngredients3: nil,
            output: 1,
            alternateOutput: nil,
            alternateOutput1: nil,
            alternateOutput2: nil,
            alternateOutput3: nil,
            category: "Test",
            imageremark: "Crafting Table",
            remarks: nil
        )

        #expect(
            CraftImageStore.imageKeys(in: [recipe])
                == ["Output", "Ingredient", "Alternate", "Crafting Table"]
        )
    }
}


extension CraftifyTests {
    @MainActor
    @Test func downloadedImagesMigrateToPersistentStorageAndClearCompletely() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let persistentDirectory = root.appendingPathComponent(
            "ApplicationSupportImages",
            isDirectory: true
        )
        let legacyDirectory = root.appendingPathComponent(
            "LegacyCacheImages",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: root) }

        let assetKey = "Blue Candle"
        let fileName = CraftImageAssetKey.recordName(for: assetKey)
        let legacyFile = legacyDirectory.appendingPathComponent(fileName)
        try Data("image-data".utf8).write(to: legacyFile)

        let suiteName = "CraftImageStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let versionKey = "craft-image.version.\(fileName)"
        defaults.set(4, forKey: versionKey)

        let imageStore = CraftImageStore(
            fileManager: fileManager,
            defaults: defaults,
            storageDirectory: persistentDirectory,
            legacyCacheDirectory: legacyDirectory
        )
        let migratedFile = persistentDirectory.appendingPathComponent(fileName)

        #expect(fileManager.fileExists(atPath: migratedFile.path))
        #expect(!fileManager.fileExists(atPath: legacyFile.path))

        try imageStore.clearDownloadedImages()

        let remainingFiles = try fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: nil
        )
        #expect(remainingFiles.isEmpty)
        #expect(defaults.object(forKey: versionKey) == nil)
    }
}

extension CraftifyTests {
    @MainActor
    @Test func newRecipeAnnouncementContainsExactRecipesSortedByRecordID() {
        let recipes = [
            announcementRecipe(id: 351, name: "Spruce Chest Boat"),
            announcementRecipe(id: 12, name: "Existing Recipe"),
            announcementRecipe(id: 349, name: "Oak Boat with Chest")
        ]

        let addedRecipes = DataManager.newlyAddedRecipes(
            in: recipes,
            comparedTo: [12]
        )

        #expect(addedRecipes.map(\.id) == [349, 351])
        #expect(
            addedRecipes.map(\.name)
                == ["Oak Boat with Chest", "Spruce Chest Boat"]
        )

        let announcement = DataManager.NewRecipeAnnouncement(
            recipes: addedRecipes
        )
        #expect(announcement.recipeCount == 2)
    }

    private func announcementRecipe(id: Int, name: String) -> Recipe {
        Recipe(
            id: id,
            name: name,
            image: name,
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
            category: "Test",
            imageremark: nil,
            remarks: nil
        )
    }
}
