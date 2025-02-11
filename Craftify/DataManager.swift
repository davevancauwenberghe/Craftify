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
    @Published var recipes: [Recipe] = []           // List of recipes
    @Published var favorites: [Recipe] = []           // List of favorite recipes
    @Published var selectedCategory: String? = nil    // Selected category for filtering
    @Published var lastUpdated: Date? = nil           // Last time recipes were updated from CloudKit
    @Published var errorMessage: String? = nil        // Error messages for UI display
    
    private let iCloudKey = "favoriteRecipes"
    
    init() {
        // Observe iCloud key-value changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // First, load recipes from the local cache (if available)
        if let localRecipes = loadRecipesFromLocalCache() {
            self.recipes = localRecipes
            self.syncFavorites()
        }
        
        // Then, load updated recipes from CloudKit.
        loadData { [weak self] in
            self?.syncFavorites() // Ensure favorites sync after recipes are loaded.
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
        
        let predicate = NSPredicate(value: true) // Fetch all recipes.
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
                    self.lastUpdated = Date()  // Update the last updated timestamp
                    completion()
                case .failure(let error):
                    self.errorMessage = "Error fetching recipes: \(error.localizedDescription)"
                    print("Error fetching recipes: \(error.localizedDescription)")
                    // Optionally, you could retry the query here.
                    completion()
                }
            }
        }
        
        publicDatabase.add(queryOperation)
    }
    
    // MARK: - Local File Cache Methods
    
    private func loadRecipesFromLocalCache() -> [Recipe]? {
        let fileURL = getDocumentsDirectory().appendingPathComponent("recipes.json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }
    
    private func saveRecipesToLocalCache(_ recipes: [Recipe]) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("recipes.json")
        if let data = try? JSONEncoder().encode(recipes) {
            try? data.write(to: fileURL)
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
        
        // Use the record's recordName as the recipe id.
        let id = Int(record.recordID.recordName) ?? 0
        
        // Convert output from Int64 to Int.
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
