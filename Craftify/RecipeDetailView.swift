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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedDetail: String?
    @State private var selectedItem: SelectedItem?
    @State private var animateHeart: Bool = false
    @State private var selectedCraftingOption: Int = 0
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State private var ingredientSets: [[String]] = []
    @State private var outputs: [Int] = []
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    
    private var craftingHeight: CGFloat { horizontalSizeClass == .regular ? 240 : 222 }
    
    enum SelectedItem: Equatable {
        case grid(index: Int)
        case output
        case imageremark
    }
    
    private func computeIngredientSets() -> [[String]] {
        let maxIngredients: Int
        switch true {
        case recipe.imageremark == "Furnace":
            maxIngredients = 2
        default:
            maxIngredients = 9
        }
        var sets: [[String]] = [recipe.ingredients]
        if let alt = recipe.alternateIngredients, !alt.isEmpty {
            sets.append(alt)
        }
        if let alt1 = recipe.alternateIngredients1, !alt1.isEmpty {
            sets.append(alt1)
        }
        if let alt2 = recipe.alternateIngredients2, !alt2.isEmpty {
            sets.append(alt2)
        }
        if let alt3 = recipe.alternateIngredients3, !alt3.isEmpty {
            sets.append(alt3)
        }
        return sets.map { set in
            set.count < maxIngredients ? set + Array(repeating: "", count: maxIngredients - set.count) : Array(set.prefix(maxIngredients))
        }
    }
    
    private func computeOutputs() -> [Int] {
        var outputs: [Int] = [recipe.output]
        if recipe.alternateIngredients != nil {
            outputs.append(recipe.alternateOutput ?? recipe.output)
        }
        if recipe.alternateIngredients1 != nil {
            outputs.append(recipe.alternateOutput1 ?? recipe.output)
        }
        if recipe.alternateIngredients2 != nil {
            outputs.append(recipe.alternateOutput2 ?? recipe.output)
        }
        if recipe.alternateIngredients3 != nil {
            outputs.append(recipe.alternateOutput3 ?? recipe.output)
        }
        return outputs
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
            
            ScrollView {
                VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                    if ingredientSets.count <= 1 {
                        Text("No alternate crafting options available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.top, 8)
                            .accessibilityLabel("No alternate crafting options available for \(recipe.name)")
                    }
                    
                    if ingredientSets.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<ingredientSets.count, id: \.self) { index in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                            selectedCraftingOption = index
                                            selectedDetail = nil
                                            selectedItem = nil
                                        }
                                    } label: {
                                        Text("Recipe \(index + 1)")
                                            .fontWeight(.bold)
                                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCraftingOption == index ? Color.userAccentColor : Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .accessibilityLabel("Recipe \(index + 1)")
                                    .accessibilityHint("Selects ingredient combination \(index + 1) for crafting \(recipe.name)")
                                }
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Crafting option picker")
                        .accessibilityHint("Select different ingredient combinations for crafting \(recipe.name)")
                    }
                    
                    GridView(
                        recipe: recipe,
                        selectedItem: $selectedItem,
                        selectedDetail: $selectedDetail,
                        craftingHeight: craftingHeight,
                        ingredients: ingredientSets.isEmpty ? [] : ingredientSets[selectedCraftingOption],
                        output: outputs.isEmpty ? recipe.output : outputs[selectedCraftingOption],
                        selectedCraftingOption: selectedCraftingOption,
                        accentColorPreference: accentColorPreference
                    )
                    .padding(.bottom, horizontalSizeClass == .regular ? 24 : 16)
                    
                    if let detail = selectedDetail {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 8) {
                                Group {
                                    if UIImage(named: detail) != nil {
                                        Image(detail)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: horizontalSizeClass == .regular ? 90 : 80, height: horizontalSizeClass == .regular ? 90 : 80)
                                            .padding(8)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(12)
                                            .accessibilityLabel("Image of \(detail)")
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: horizontalSizeClass == .regular ? 90 : 80, height: horizontalSizeClass == .regular ? 90 : 80)
                                            .padding(8)
                                            .foregroundColor(.gray)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(12)
                                            .accessibilityLabel("Image unavailable for \(detail)")
                                    }
                                }
                                Text(detail)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                
                                Text(
                                    selectedItem == .imageremark
                                        ? (recipe.remarks?.isEmpty == false ? recipe.remarks! : "No remarks available")
                                        : (detail == recipe.name ? "Output of crafting" : "Ingredient for \(recipe.name)")
                                )
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                ZStack {
                                    Color(.systemGray5)
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.userAccentColor, lineWidth: 2)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(
                                    color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3),
                                    radius: colorScheme == .light ? 6 : 8
                                )
                            )
                            
                            Button {
                                feedbackGenerator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    selectedDetail = nil
                                    selectedItem = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.userAccentColor)
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
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        .padding(.bottom, horizontalSizeClass == .regular ? 24 : 16)
                        .transition(.scale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selectedDetail)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(
                            selectedItem == .imageremark
                                ? "Remark: \(recipe.remarks?.isEmpty == false ? recipe.remarks! : "No remarks available")"
                                : (detail == recipe.name ? "Output: \(detail)" : "Ingredient: \(detail)")
                        )
                        .accessibilityHint("Tap the close button or select another item to dismiss")
                    }
                    
                    VStack(spacing: 8) {
                        if recipe.imageremark?.isEmpty == false {
                            if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(width: horizontalSizeClass == .regular ? 45 : 40, height: horizontalSizeClass == .regular ? 45 : 40)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            selectedItem == .imageremark
                                            ? RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.userAccentColor, lineWidth: 2)
                                                .shadow(radius: 4)
                                            : nil
                                        )
                                    if UIImage(named: imageRemark) != nil {
                                        Image(imageRemark)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: horizontalSizeClass == .regular ? 28 : 24, height: horizontalSizeClass == .regular ? 28 : 24)
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: horizontalSizeClass == .regular ? 28 : 24, height: horizontalSizeClass == .regular ? 28 : 24)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .accessibilityLabel("Remark image: \(imageRemark)")
                                .accessibilityHint("Tap to view details and remarks for \(imageRemark)")
                                .onTapGesture {
                                    feedbackGenerator.impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        selectedDetail = imageRemark
                                        selectedItem = .imageremark
                                    }
                                }
                            }
                        }
                        
                        if !recipe.category.isEmpty {
                            Text("Category: \(recipe.category)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                .background(
                                    Color(.systemGray5)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                )
                                .accessibilityLabel("Category: \(recipe.category)")
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .padding(.vertical, 16)
                .padding(.bottom, 50)
            }
            .id(accentColorPreference) // Force redraw when accent color changes
            .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
            .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            .accessibilityElement(children: .contain)
            .onAppear {
                feedbackGenerator.prepare()
                ingredientSets = computeIngredientSets()
                outputs = computeOutputs()
                print("RecipeDetailView: \(recipe.name), category: \(recipe.category), alternateIngredients: \(String(describing: recipe.alternateIngredients)), alternateOutput: \(String(describing: recipe.alternateOutput)), alternateIngredients1: \(String(describing: recipe.alternateIngredients1)), alternateOutput1: \(String(describing: recipe.alternateOutput1)), alternateIngredients2: \(String(describing: recipe.alternateIngredients2)), alternateOutput2: \(String(describing: recipe.alternateOutput2)), alternateIngredients3: \(String(describing: recipe.alternateIngredients3)), alternateOutput3: \(String(describing: recipe.alternateOutput3))")
                print("RecipeDetailView bounds: \(UIScreen.main.bounds)")
            }
            .onChange(of: ingredientSets.count) { _, _ in
                print("Ingredient sets count: \(ingredientSets.count)")
            }
            .onChange(of: dataManager.isLoading) { _, newValue in
                if !newValue && dataManager.isManualSyncing {
                    dataManager.syncFavorites()
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    feedbackGenerator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        animateHeart = true
                    }
                    dataManager.toggleFavorite(recipe: recipe)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { animateHeart = false }
                    }
                } label: {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(Color.userAccentColor)
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
                .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Toggles favorite status for \(recipe.name)")
            }
        }
    }
}

struct GridView: View {
    let recipe: Recipe
    @Binding var selectedItem: RecipeDetailView.SelectedItem?
    @Binding var selectedDetail: String?
    let craftingHeight: CGFloat
    let ingredients: [String]
    let output: Int
    let selectedCraftingOption: Int
    let accentColorPreference: String
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                switch true {
                case recipe.imageremark == "Furnace":
                    VStack(spacing: 6) {
                        HStack {
                            Spacer()
                            GridCell(
                                index: 0,
                                ingredient: ingredients.count > 0 ? ingredients[0] : "",
                                isSelected: selectedItem == .grid(index: 0),
                                feedbackGenerator: feedbackGenerator,
                                cellSize: horizontalSizeClass == .regular ? 80 : 70,
                                accentColorPreference: accentColorPreference
                            ) { selectedDetail = ingredients.count > 0 ? ingredients[0] : ""; selectedItem = .grid(index: 0) }
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            Image(UIImage(named: "Furnace Fire") != nil ? "Furnace Fire" : "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: horizontalSizeClass == .regular ? 45 : 40, height: horizontalSizeClass == .regular ? 45 : 40)
                                .frame(width: horizontalSizeClass == .regular ? 80 : 70, height: horizontalSizeClass == .regular ? 80 : 70)
                                .accessibilityLabel("Furnace Fire slot")
                                .accessibilityHint("Represents the furnace in the crafting process")
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            GridCell(
                                index: 1,
                                ingredient: ingredients.count > 1 ? ingredients[1] : "",
                                isSelected: selectedItem == .grid(index: 1),
                                feedbackGenerator: feedbackGenerator,
                                cellSize: horizontalSizeClass == .regular ? 80 : 70,
                                accentColorPreference: accentColorPreference
                            ) { selectedDetail = ingredients.count > 1 ? ingredients[1] : ""; selectedItem = .grid(index: 1) }
                            Spacer()
                        }
                    }
                    .frame(width: craftingHeight, height: craftingHeight)
                
                default:
                    VStack(spacing: 6) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 6) {
                                ForEach(0..<3) { col in
                                    let index = row * 3 + col
                                    GridCell(
                                        index: index,
                                        ingredient: index < ingredients.count ? ingredients[index] : "",
                                        isSelected: selectedItem == .grid(index: index),
                                        feedbackGenerator: feedbackGenerator,
                                        cellSize: horizontalSizeClass == .regular ? 80 : 70,
                                        accentColorPreference: accentColorPreference
                                    ) { selectedDetail = index < ingredients.count ? ingredients[index] : ""; selectedItem = .grid(index: index) }
                                }
                            }
                        }
                    }
                    .frame(width: craftingHeight, height: craftingHeight)
                }
                
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: horizontalSizeClass == .regular ? 45 : 40, height: craftingHeight)
                    .accessibilityHidden(true)
                
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: horizontalSizeClass == .regular ? 80 : 70, height: horizontalSizeClass == .regular ? 80 : 70)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .overlay(
                                selectedItem == .output
                                ? RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.userAccentColor, lineWidth: 2)
                                    .shadow(radius: 4)
                                : nil
                            )
                        
                        if UIImage(named: recipe.image) != nil {
                            Image(recipe.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: horizontalSizeClass == .regular ? 70 : 60, height: horizontalSizeClass == .regular ? 70 : 60)
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: horizontalSizeClass == .regular ? 70 : 60, height: horizontalSizeClass == .regular ? 70 : 60)
                                .foregroundColor(.gray)
                        }
                    }
                    .accessibilityLabel(recipe.imageremark ?? "Output: \(recipe.name)")
                    .accessibilityHint("Tap to view details for \(recipe.name)")
                    .onTapGesture {
                        feedbackGenerator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            selectedDetail = recipe.name
                            selectedItem = .output
                        }
                    }
                    
                    Text("x\(output)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .accessibilityLabel("Output quantity: \(output)")
                }
                .frame(height: craftingHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
        }
        .frame(height: craftingHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selectedCraftingOption)
        .onAppear {
            feedbackGenerator.prepare()
        }
    }
}

struct GridCell: View {
    let index: Int
    let ingredient: String
    let isSelected: Bool
    let feedbackGenerator: UIImpactFeedbackGenerator
    let cellSize: CGFloat
    let accentColorPreference: String
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(!ingredient.isEmpty ? Color(.systemGray5) : Color(.systemGray6))
                .frame(width: cellSize, height: cellSize)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    isSelected
                    ? RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.userAccentColor, lineWidth: 2)
                        .shadow(radius: 4)
                    : nil
                )
            
            if !ingredient.isEmpty {
                if UIImage(named: ingredient) != nil {
                    Image(ingredient)
                        .resizable()
                        .scaledToFit()
                        .frame(width: cellSize - 10, height: cellSize - 10)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: cellSize - 10, height: cellSize - 10)
                        .foregroundColor(.gray)
                }
            }
        }
        .accessibilityLabel(!ingredient.isEmpty ? "Ingredient: \(ingredient)" : "Empty slot")
        .accessibilityHint(!ingredient.isEmpty ? "Tap to view details for \(ingredient)" : "")
        .onTapGesture {
            guard !ingredient.isEmpty else { return }
            feedbackGenerator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                onTap()
            }
        }
    }
}
