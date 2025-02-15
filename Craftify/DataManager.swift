//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import Combine
import CloudKit

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var favorites: [Recipe] = []
    @Published var selectedCategory: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var cacheClearedMessage: String? = nil // Message for UI feedback

    private let iCloudKey = "favoriteRecipes"

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        // Load from local cache first.
        if let localRecipes = loadRecipesFromLocalCache() {
            print("Loaded \(localRecipes.count) recipes from local cache.")
            self.recipes = localRecipes
            self.syncFavorites()
        } else {
            print("No local cache found; will fetch from CloudKit.")
        }

        // Then fetch from CloudKit.
        loadData {
            self.syncFavorites()
        }
    }

    // MARK: - Favorite Handling

    func isFavorite(recipe: Recipe) -> Bool {
        return favorites.contains { $0.id == recipe.id }
    }

    func toggleFavorite(recipe: Recipe) {
        if let index = favorites.firstIndex(where: { $0.id == recipe.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(recipe)
        }
        saveFavorites()
    }

    func saveFavorites() {
        let favoriteIDs = favorites.map { $0.id }
        NSUbiquitousKeyValueStore.default.set(favoriteIDs, forKey: iCloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func syncFavorites() {
        if let savedIDs = NSUbiquitousKeyValueStore.default.array(forKey: iCloudKey) as? [Int] {
            favorites = recipes.filter { savedIDs.contains($0.id) }
        }
    }

    @objc private func icloudDidChange() {
        syncFavorites()
    }

    // MARK: - CloudKit & Local File Caching

    func loadData(completion: @escaping () -> Void) {
        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)

        let queryOperation = CKQueryOperation(query: query)
        queryOperation.resultsLimit = CKQueryOperation.maximumResults

        var fetchedRecipes: [Recipe] = []

        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                if let recipe = self.convertRecordToRecipe(record) {
                    fetchedRecipes.append(recipe)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching record \(recordID.recordName): \(error.localizedDescription)"
                }
                print("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
            }
        }

        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.recipes = fetchedRecipes
                    self.syncFavorites()
                    self.saveRecipesToLocalCache(fetchedRecipes)
                    self.lastUpdated = Date()
                    completion()
                case .failure(let error):
                    self.errorMessage = "Error fetching recipes: \(error.localizedDescription)"
                    print("Error fetching recipes: \(error.localizedDescription)")
                    completion()
                }
            }
        }

        publicDatabase.add(queryOperation)
    }

    // Asynchronous wrapper using async/await.
    func loadDataAsync() async {
        await withCheckedContinuation { continuation in
            loadData {
                continuation.resume()
            }
        }
    }

    // MARK: - Local File Cache Methods

    // Always use "recipes.json" regardless of environment.
    private func localCacheFileName() -> String {
        return "recipes.json"
    }

    private func loadRecipesFromLocalCache() -> [Recipe]? {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        print("Attempting to load local cache from: \(fileURL.path)")
        guard let data = try? Data(contentsOf: fileURL) else {
            print("No data found at \(fileURL.path)")
            return nil
        }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }

    private func saveRecipesToLocalCache(_ recipes: [Recipe]) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        if let data = try? JSONEncoder().encode(recipes) {
            do {
                try data.write(to: fileURL)
                print("Saved \(recipes.count) recipes to local cache at \(fileURL.path)")
            } catch {
                print("Error saving recipes to local cache: \(error.localizedDescription)")
            }
        }
    }

    // On iOS, we use the Documents directory for caching.
    private func getCacheDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Clear Cache

    func clearCache(completion: @escaping (Bool) -> Void) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        do {
            try FileManager.default.removeItem(at: fileURL)
            DispatchQueue.main.async {
                self.recipes = []
                self.cacheClearedMessage = "Cache cleared successfully."
            }
            completion(true)
        } catch {
            DispatchQueue.main.async {
                self.cacheClearedMessage = "Failed to clear cache."
            }
            completion(false)
        }
    }

    // MARK: - Record Conversion

    private func convertRecordToRecipe(_ record: CKRecord) -> Recipe? {
        guard let name = record["name"] as? String,
              let image = record["image"] as? String,
              let ingredients = record["ingredients"] as? [String],
              let outputInt64 = record["output"] as? Int64,
              let category = record["category"] as? String else {
            print("Missing field in record \(record.recordID.recordName)")
            return nil
        }
        let id = Int(record.recordID.recordName) ?? 0
        let output = Int(outputInt64)
        return Recipe(id: id, name: name, image: image, ingredients: ingredients, output: output, category: category)
    }

    // MARK: - Helper Properties

    var categories: [String] {
        let uniqueCategories = Set(recipes.map { $0.category })
        return Array(uniqueCategories).sorted()
    }

    var filteredRecipes: [Recipe] {
        if let category = selectedCategory {
            return recipes.filter { $0.category == category }
        } else {
            return recipes
        }
    }
}

extension CKError {
    var isRetryable: Bool {
        switch self.code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
            return true
        default:
            return false
        }
    }
}
