//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []  // List of recipes
    @Published var favorites: [Recipe] = []  // List of favorite recipes

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
    }
    
    // Load data from the local JSON file
    func loadData() {
        // Locate the JSON file in the app bundle
        if let url = Bundle.main.url(forResource: "recipes", withExtension: "json") {
            do {
                // Read the data from the file
                let data = try Data(contentsOf: url)
                
                // Decode the data into an array of Recipe objects
                let decodedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
                
                // Set the recipes array with the decoded data
                self.recipes = decodedRecipes
            } catch {
                print("Error loading data: \(error.localizedDescription)")
            }
        } else {
            print("Recipe JSON file not found.")
        }
    }
}
