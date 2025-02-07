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
    @State private var selectedIngredient: String?

    var body: some View {
        VStack {
            Spacer()
            
            // Crafting Grid & Output Side by Side
            HStack(alignment: .center, spacing: 16) {
                // 3x3 Crafting Grid
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                    Image(recipe.ingredients[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        .onTapGesture {
                                            selectedIngredient = recipe.ingredients[index]
                                        }
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(Color.gray.opacity(0.1))
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                    }
                }
                
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 60)
                
                // Output Item
                VStack {
                    Image(recipe.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text("x\(recipe.output)")
                        .font(.headline)
                }
            }
            
            Spacer()
            
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
            
            // Category Display
            Text("Category: \(recipe.category)")
                .font(.headline)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .padding()
        .navigationTitle(recipe.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    dataManager.toggleFavorite(recipe: recipe)
                }) {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
        }
    }
}

