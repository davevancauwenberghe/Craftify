//
//  RecipeListView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject private var dataManager: DataManager  // Access DataManager via EnvironmentObject
    @State private var searchText = ""
    
    var filteredRecipes: [Recipe] {
        let filtered = searchText.isEmpty ? dataManager.filteredRecipes : dataManager.filteredRecipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered
    }

    var body: some View {
        NavigationView {
            VStack {
                // Category Picker
                Picker("Category", selection: $dataManager.selectedCategory) {
                    Text("All").tag(nil as String?)
                    ForEach(dataManager.categories, id: \.self) { category in
                        Text(category).tag(category as String?)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                List(filteredRecipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
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


