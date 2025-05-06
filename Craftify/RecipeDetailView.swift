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

    // Fixed height for the crafting grid
    private let craftingHeight: CGFloat = 222

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Crafting grid and output item side-by-side
                HStack(alignment: .center, spacing: 16) {
                    // Left: 3x3 Crafting Grid
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
                                            if UIImage(named: recipe.ingredients[index]) != nil {
                                                Image(recipe.ingredients[index])
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 60, height: 60)
                                            } else {
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 60, height: 60)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .accessibilityLabel(
                                        index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty
                                        ? "Ingredient: \(recipe.ingredients[index])"
                                        : "Empty crafting slot"
                                    )
                                    .accessibilityHint(
                                        index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty
                                        ? "Tap to view details for \(recipe.ingredients[index])"
                                        : ""
                                    )
                                    .onTapGesture {
                                        guard index < recipe.ingredients.count,
                                              !recipe.ingredients[index].isEmpty else { return }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                            selectedDetail = recipe.ingredients[index]
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: craftingHeight)
                    
                    // Middle: Arrow indicator
                    Image(systemName: "arrow.right")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .frame(width: 40, height: craftingHeight)
                        .accessibilityHidden(true)
                    
                    // Right: Output Item
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            if UIImage(named: recipe.image) != nil {
                                Image(recipe.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                        }
                        .accessibilityLabel(recipe.imageremark ?? "Output: \(recipe.name)")
                        .accessibilityHint("Tap to view details for \(recipe.name)")
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                selectedDetail = recipe.name
                            }
                        }
                        
                        Text("x\(recipe.output)")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .accessibilityLabel("Output quantity: \(recipe.output)")
                        Spacer()
                    }
                    .frame(height: craftingHeight)
                }
                
                Spacer()
                
                // Modernized ingredients popup (inline)
                if let detail = selectedDetail {
                    ZStack {
                        VStack(spacing: 12) {
                            // Item image
                            if UIImage(named: detail) != nil {
                                Image(detail)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .padding(8)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .accessibilityLabel("Image of \(detail)")
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .padding(8)
                                    .foregroundColor(.gray)
                                    .background(Color(UIColor.systemGray5))
                                    .cornerRadius(12)
                                    .accessibilityLabel("Image unavailable for \(detail)")
                            }
                            
                            // Item name
                            Text(detail)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            // Description
                            Text(detail == recipe.name ? "Output of crafting" : "Ingredient for \(recipe.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(
                            ZStack {
                                Color(UIColor.systemGray5)
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "00AA00"), lineWidth: 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                        )
                        .padding(.horizontal, 32)
                        .transition(.scale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selectedDetail)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(detail == recipe.name ? "Output: \(detail)" : "Ingredient: \(detail)")
                        .accessibilityHint("Tap another item to view its details or close to dismiss")
                        
                        // Close button (top-right X)
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        selectedDetail = nil
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(hex: "00AA00"))
                                        .background(
                                            Circle()
                                                .fill(Color(UIColor.systemGray5))
                                                .frame(width: 30, height: 30)
                                        )
                                        .frame(width: 30, height: 30)
                                        .padding(8)
                                }
                                .accessibilityLabel("Close popup")
                                .accessibilityHint("Dismisses the details for \(detail)")
                            }
                            Spacer()
                        }
                    }
                }
                
                // Display remarks (if any)
                if (recipe.imageremark?.isEmpty == false) || (recipe.remarks?.isEmpty == false) {
                    VStack(spacing: 8) {
                        if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                if UIImage(named: imageRemark) != nil {
                                    Image(imageRemark)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.gray)
                                }
                            }
                            .accessibilityLabel("Remark image: \(imageRemark)")
                            .accessibilityHint("Tap to view details for \(imageRemark)")
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    selectedDetail = imageRemark
                                }
                            }
                        }
                        if let remark = recipe.remarks, !remark.isEmpty {
                            Text(remark)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Remark: \(remark)")
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        animateHeart = true
                    }
                    dataManager.toggleFavorite(recipe: recipe)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { animateHeart = false }
                    }
                }) {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(Color(hex: "00AA00"))
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
                .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Toggles favorite status for \(recipe.name)")
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
                        .accessibilityLabel("Category: \(recipe.category)")
                }
            }
            .padding(.bottom, 16),
            alignment: .bottom
        )
        .onAppear {
            // Preload haptics
            UIImpactFeedbackGenerator(style: .medium).prepare()
        }
    }
}
