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
    @State private var selectedItem: SelectedItem?
    @State private var animateHeart: Bool = false

    private let craftingHeight: CGFloat = 222

    enum SelectedItem: Equatable {
        case grid(index: Int)
        case output
        case imageremark
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Centering spacer when no popup
                    if selectedDetail == nil {
                        Spacer()
                            .frame(minHeight: 50)
                    }
                    
                    // Crafting grid and output
                    GridView(
                        recipe: recipe,
                        selectedItem: $selectedItem,
                        selectedDetail: $selectedDetail,
                        craftingHeight: craftingHeight
                    )
                    
                    // Spacer to separate grid from popup
                    if selectedDetail != nil {
                        Spacer()
                            .frame(height: 24)
                    }
                    
                    // Ingredients popup
                    if let detail = selectedDetail {
                        ZStack(alignment: .topTrailing) {
                            // Popup content
                            VStack(spacing: 8) {
                                // Item image
                                Group {
                                    if UIImage(named: detail) != nil {
                                        Image(detail)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .padding(8)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(12)
                                            .accessibilityLabel("Image of \(detail)")
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .padding(8)
                                            .foregroundColor(.gray)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(12)
                                            .accessibilityLabel("Image unavailable for \(detail)")
                                    }
                                }
                                
                                // Item name
                                Text(detail)
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                
                                // Description
                                Text(detail == recipe.name ? "Output of crafting" : "Ingredient for \(recipe.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            
                            // Close button
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    selectedDetail = nil
                                    selectedItem = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(hex: "00AA00"))
                                    .background(
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 24, height: 24)
                                            .shadow(radius: 2)
                                    )
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.top, 4)
                            .padding(.trailing, 4)
                            .accessibilityLabel("Close popup")
                            .accessibilityHint("Dismisses the details for \(detail)")
                        }
                        .frame(width: 300)
                        .background(
                            ZStack {
                                Color(.systemGray5)
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
                        .accessibilityHint("Tap the close button or select another item to dismiss")
                    }
                    
                    // Spacer to push remarks and category label down
                    if selectedDetail != nil {
                        Spacer()
                            .frame(height: 32)
                    }
                    
                    // Remarks
                    if recipe.imageremark?.isEmpty == false || recipe.remarks?.isEmpty == false {
                        VStack(spacing: 8) {
                            if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 40, height: 40)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            selectedItem == .imageremark
                                            ? RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "00AA00"), lineWidth: 2)
                                                .shadow(radius: 4)
                                            : nil
                                        )
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
                                        selectedItem = .imageremark
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
                    
                    // Category label
                    if !recipe.category.isEmpty {
                        Text("Category: \(recipe.category)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                ZStack {
                                    Color(.systemGray5)
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "00AA00"), lineWidth: 2)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 8)
                            )
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                            .accessibilityLabel("Category: \(recipe.category)")
                    }
                    
                    // Extra spacer for scrollable content
                    Spacer()
                        .frame(height: 32)
                }
                .padding()
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selectedDetail)
            }
            .accessibilityElement(children: .contain)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        animateHeart = true
                    }
                    dataManager.toggleFavorite(recipe: recipe)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            animateHeart = false
                        }
                    }
                } label: {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(Color(hex: "00AA00"))
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
                .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Toggles favorite status for \(recipe.name)")
            }
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).prepare()
        }
    }
}

// Extracted GridView to avoid code duplication
struct GridView: View {
    let recipe: Recipe
    @Binding var selectedItem: RecipeDetailView.SelectedItem?
    @Binding var selectedDetail: String?
    let craftingHeight: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 3x3 Crafting Grid
            VStack(spacing: 6) {
                ForEach(0..<3) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty
                                        ? Color(.systemGray5)
                                        : Color(.systemGray6)
                                    )
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .overlay(
                                        selectedItem == .grid(index: index)
                                        ? RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "00AA00"), lineWidth: 2)
                                            .shadow(radius: 4)
                                        : nil
                                    )
                                
                                if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                    if UIImage(named: recipe.ingredients[index]) != nil {
                                        Image(recipe.ingredients[index])
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
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
                                guard index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    selectedDetail = recipe.ingredients[index]
                                    selectedItem = .grid(index: index)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: craftingHeight)
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .frame(width: 40, height: craftingHeight)
                .accessibilityHidden(true)
            
            // Output Item
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .overlay(
                            selectedItem == .output
                            ? RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "00AA00"), lineWidth: 2)
                                .shadow(radius: 4)
                            : nil
                        )
                    
                    if UIImage(named: recipe.image) != nil {
                        Image(recipe.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
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
                        selectedItem = .output
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
    }
}
