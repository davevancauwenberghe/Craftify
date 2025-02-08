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
    @State private var selectedDetail: String?  // Single state variable for tapped detail
    @State private var animateHeart = false     // Drives heart animation

    var body: some View {
        VStack {
            Spacer()
            
            // Crafting Grid & Output Side by Side
            HStack(alignment: .center, spacing: 16) {
                // 3x3 Crafting Grid for ingredients
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \ .self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \ .self) { col in
                                let index = row * 3 + col
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                        Image(recipe.ingredients[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                    }
                                }
                                .onTapGesture {
                                    if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        selectedDetail = recipe.ingredients[index]
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Arrow indicator between grid and output
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 60)
                
                // Output Item styled similarly to grid cells
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        Image(recipe.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectedDetail = recipe.name
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
                    .font(.title2).bold()
                    .padding()
                    .background(Color(UIColor.systemGray3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDetail)
            }
            
            // Category Display (informational style)
            Text("Category: \(recipe.category)")
                .font(.headline)
                .padding()
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large) // Ensures large title under the back button
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
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
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: animateHeart)
                }
            }
        }
    }
}
