//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationView {
            List(dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
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
