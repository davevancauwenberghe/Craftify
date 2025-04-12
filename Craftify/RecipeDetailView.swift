//
//  RecipeDetailView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import CloudKit

struct RecipeDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedDetail: String?
    @State private var animateHeart = false

    // Fixed height for the crafting grid.
    private let craftingHeight: CGFloat = 222

    var body: some View {
        ZStack {
            // Revert to default system background for both light and dark modes.
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Crafting grid and output item side-by-side.
                HStack(alignment: .center, spacing: 16) {
                    // Left: 3x3 Crafting Grid.
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row * 3 + col
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                (index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty)
                                                ? Color(UIColor.systemGray5)
                                                : Color(UIColor.systemGray6)
                                            )
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
                                        guard index < recipe.ingredients.count,
                                              !recipe.ingredients[index].isEmpty else { return }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDetail = recipe.ingredients[index]
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: craftingHeight)
                    
                    // Middle: Arrow indicator.
                    Image(systemName: "arrow.right")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .frame(width: 40, height: craftingHeight)
                    
                    // Right: Output Item.
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Image(recipe.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                        }
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDetail = recipe.name
                            }
                        }
                        
                        Text("x\(recipe.output)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(height: craftingHeight)
                }
                
                Spacer()
                
                // Display tapped detail, if any.
                if let detail = selectedDetail {
                    Text(detail)
                        .font(.title2)
                        .bold()
                        .padding()
                        .background(Color(UIColor.systemGray3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .animation(.easeInOut, value: selectedDetail)
                }
                
                // Display remarks (if any).
                if (recipe.imageremark?.isEmpty == false) || (recipe.remarks?.isEmpty == false) {
                    VStack(spacing: 8) {
                        if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                Image(imageRemark)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDetail = imageRemark
                                }
                            }
                        }
                        if let remark = recipe.remarks, !remark.isEmpty {
                            Text(remark)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
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
                        withAnimation { animateHeart = false }
                    }
                }) {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                if !recipe.category.isEmpty {
                    Text("Category: \(recipe.category)")
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.systemGray5).opacity(0.7))
                        .foregroundColor(.primary)
                        .cornerRadius(20)
                }
            }
            .padding(.bottom, 16),
            alignment: .bottom
        )
    }
}
