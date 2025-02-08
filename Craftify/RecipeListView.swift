//
//  RecipeListView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Binding var navigationPath: NavigationPath // Binding for navigation control
    @State private var searchText = ""
    
    var filteredRecipes: [Recipe] {
        // Use dataManager.filteredRecipes as a base, then filter by searchText if needed.
        let filtered = searchText.isEmpty ? dataManager.filteredRecipes : dataManager.filteredRecipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered
    }

    var body: some View {
        NavigationStack(path: $navigationPath) { // NavigationStack with bound path
            VStack {
                // Picker for category selection
                Picker("Category", selection: $dataManager.selectedCategory) {
                    Text("All").tag(nil as String?)
                    ForEach(dataManager.categories, id: \.self) { category in
                        Text(category).tag(category as String?)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // List of filtered recipes with NavigationLink to detail view
                List(filteredRecipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                        HStack {
                            Image(recipe.image)
                                .resizable()
                                .frame(width: 50, height: 50)
                            Text(recipe.name)
                        }
                    }
                }
                .navigationTitle("Minecraft Crafting")
                .searchable(text: $searchText, prompt: "Search recipes")
            }
        }
    }
}

