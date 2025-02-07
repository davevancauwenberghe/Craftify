//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []  // List of recipes
    @Published var favorites: [Recipe] = []  // List of favorite recipes
    @Published var selectedCategory: String? = nil  // Selected category for filtering
    
    private let iCloudKey = "favoriteRecipes"
    
    init() {
        syncFavorites() // Sync bij app-opstart
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }

    // Check if a recipe is in favorites
    func isFavorite(recipe: Recipe) -> Bool {
        return favorites.contains { $0.id == recipe.id }
    }

    // Toggle favorite status for a recipe
    func toggleFavorite(recipe: Recipe) {
        if let index = favorites.firstIndex(where: { $0.id == recipe.id }) {
            favorites.remove(at: index)  // Remove from favorites
        } else {
            favorites.append(recipe)  // Add to favorites
        }
        saveFavorites()
    }

    // Save favorites to iCloud
    func saveFavorites() {
        let favoriteIDs = favorites.map { $0.id }
        NSUbiquitousKeyValueStore.default.set(favoriteIDs, forKey: iCloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // Sync favorites from iCloud
    func syncFavorites() {
        if let savedIDs = NSUbiquitousKeyValueStore.default.array(forKey: iCloudKey) as? [Int] {
            favorites = recipes.filter { savedIDs.contains($0.id) }
        }
    }

    // Detect iCloud changes
    @objc private func icloudDidChange() {
        syncFavorites()
    }

    // Load data from the local JSON file
    func loadData() {
        if let url = Bundle.main.url(forResource: "recipes", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decodedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
                self.recipes = decodedRecipes
                syncFavorites() // Update favorieten na laden van data
            } catch {
                print("Error loading data: \(error.localizedDescription)")
            }
        } else {
            print("Recipe JSON file not found.")
        }
    }

    // Get unique categories from the recipes
    var categories: [String] {
        let uniqueCategories = Set(recipes.map { $0.category })
        return Array(uniqueCategories).sorted()
    }

    // Get filtered recipes by selected category
    var filteredRecipes: [Recipe] {
        if let category = selectedCategory {
            return recipes.filter { $0.category == category }
        } else {
            return recipes
        }
    }
}
