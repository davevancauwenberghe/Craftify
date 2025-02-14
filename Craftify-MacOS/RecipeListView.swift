//
//  RecipeListView.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct RecipeListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Group recipes alphabetically and filter by search text.
    var sortedRecipes: [String: [Recipe]] {
        let filtered: [Recipe] = {
            if searchText.isEmpty {
                return dataManager.recipes
            } else {
                return dataManager.recipes.filter { recipe in
                    recipe.name.localizedCaseInsensitiveContains(searchText) ||
                    recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }()
        let grouped = Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
        return grouped.mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(sortedRecipes.keys.sorted(), id: \.self) { letter in
                    Section(header:
                        Text(letter)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.vertical, 4)
                    ) {
                        ForEach(sortedRecipes[letter] ?? []) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                HStack {
                                    Image(recipe.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .padding(4)
                                    
                                    VStack(alignment: .leading) {
                                        Text(recipe.name)
                                            .font(.headline)
                                            .bold()
                                        Text(recipe.category)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .onChange(of: searchText) { _, newValue in
                isSearching = !newValue.isEmpty
            }
            .navigationTitle("Recipes")
            // Note: Removed the navigationBarTitleDisplayMode modifier as it's iOS‑specific.
        }
    }
}
