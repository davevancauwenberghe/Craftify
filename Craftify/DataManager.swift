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
    @Published var favorites: [Recipe] = []        // List of favorite recipes
    @Published var selectedCategory: String? = nil // Selected category for filtering
    @Published var errorMessage: String? = nil     // Holds any error messages for UI display
    
    private let iCloudKey = "favoriteRecipes"
    
    init() {
        // Observe iCloud key-value changes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // Load recipes from CloudKit with a completion handler.
        loadData { [weak self] in
            self?.syncFavorites() // Ensures favorites sync only after recipes are loaded.
        }
    }
    
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
    }
    
    func syncFavorites() {
        if let savedIDs = NSUbiquitousKeyValueStore.default.array(forKey: iCloudKey) as? [Int] {
            favorites = recipes.filter { savedIDs.contains($0.id) }
        }
    }
    
    @objc private func icloudDidChange() {
        syncFavorites()
    }
    
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
                    completion() // Call completion after setting recipes.
                case .failure(let error):
                    self.errorMessage = "Error fetching recipes: \(error.localizedDescription)"
                    print("Error fetching recipes: \(error.localizedDescription)")
                    
                    // Retry logic for transient errors
                    if let ckError = error as? CKError, ckError.isRetryable {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                            self.loadData(completion: completion)
                        }
                    }
                }
            }
        }
        
        publicDatabase.add(queryOperation)
    }
    
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
