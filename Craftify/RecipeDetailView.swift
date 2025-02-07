//
//  RecipeDetailView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedIngredient: String? // Holds the tapped ingredient name
    
    var body: some View {
        VStack {
            Text(recipe.name)
                .font(.largeTitle)
                .padding()
            
            HStack {
                // Crafting Grid
                VStack {
                    ForEach(0..<3, id: \.self) { row in
                        HStack {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                    Image(recipe.ingredients[index])
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            selectedIngredient = recipe.ingredients[index]
                                        }
                                } else {
                                    Rectangle()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(Color.gray.opacity(0.1)) // Ensure empty slots are visible
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .padding()
                
                // Output Item
                VStack {
                    Image(recipe.image)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    Text("x\(recipe.output)")
                        .font(.headline)
                }
            }
            .padding()
            
            // Show ingredient name when tapped
            if let ingredient = selectedIngredient {
                Text(ingredient)
                    .font(.title2)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedIngredient)
            }
            
            // Favorite Button
            Button(action: {
                dataManager.toggleFavorite(recipe: recipe)
            }) {
                Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                    .foregroundColor(.red)
                    .font(.largeTitle)
            }
            .padding()
            
            // Category Display
            Text("Category: \(recipe.category)")
                .font(.headline)
                .padding()
        }
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Recipes") {
                    navigationPath = NavigationPath() // Reset navigation to go back to the homepage
                }
            }
        }
    }
}
