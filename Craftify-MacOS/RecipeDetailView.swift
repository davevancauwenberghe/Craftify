//
//  RecipeDetailView.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedDetail: String?
    @State private var animateHeart = false

    var body: some View {
        VStack {
            // Header with recipe title and favorite button.
            HStack {
                Text(recipe.name)
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        animateHeart = true
                    }
                    dataManager.toggleFavorite(recipe: recipe)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            animateHeart = false
                        }
                    }
                }) {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                        .font(.title)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
            }
            .padding()

            Spacer()

            // Crafting grid and output side by side.
            HStack(alignment: .center, spacing: 16) {
                // 3x3 crafting grid for ingredients.
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill((index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty)
                                              ? Color(NSColor.windowBackgroundColor)
                                              : Color(NSColor.controlBackgroundColor))
                                        .frame(width: 70, height: 70)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                        Image(recipe.ingredients[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                                .onTapGesture {
                                    guard index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDetail = recipe.ingredients[index]
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Arrow indicator between grid and output.
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 60)
                
                // Output item styled similarly to grid cells.
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        Image(recipe.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDetail = recipe.name
                        }
                    }
                    Text("x\(recipe.output)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Display tapped detail (ingredient or output) if available.
            if let detail = selectedDetail {
                Text(detail)
                    .font(.title2)
                    .bold()
                    .padding()
                    .background(Color(NSColor.secondaryLabelColor))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDetail)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(recipe.name)
    }
}
