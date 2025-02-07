//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath() // Voeg navigationPath toe

    var body: some View {
        NavigationStack(path: $navigationPath) { // Gebruik NavigationStack met path
            List(dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                    HStack {
                        Image(recipe.image)
                            .resizable()
                            .frame(width: 50, height: 50)
                        Text(recipe.name)
                    }
                }
            }
            .navigationTitle("Favorite Recipes")
        }
    }
}
