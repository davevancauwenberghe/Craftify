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
    @State private var selectedCraftingOption: Int = 0
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State private var ingredientSets: [[String]] = []
    @State private var outputs: [Int] = []
    
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
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: min(geometry.size.height * 0.02, 16)) {
                        if ingredientSets.count <= 1 {
                            Text("No alternate crafting options available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, min(geometry.size.width * 0.04, 16))
                                .padding(.top, min(geometry.size.height * 0.01, 8))
                                .accessibilityLabel("No alternate crafting options available for \(recipe.name)")
                        } else {
                            AlternateCraftingView(
                                ingredientSets: ingredientSets,
                                selectedCraftingOption: $selectedCraftingOption,
                                selectedDetail: $selectedDetail,
                                craftingSelectedItem: $selectedItem,
                                geometry: geometry,
                                recipeName: recipe.name
                            )
                        }
                        
                        GridView(
                            recipe: recipe,
                            selectedItem: $selectedItem,
                            selectedDetail: $selectedDetail,
                            ingredients: ingredientSets.isEmpty ? [] : ingredientSets[selectedCraftingOption],
                            output: outputs.isEmpty ? recipe.output : outputs[selectedCraftingOption],
                            geometry: geometry
                        )
                        
                        if let detail = selectedDetail {
                            DetailPopupView(
                                detail: detail,
                                selectedItem: selectedItem,
                                recipe: recipe,
                                feedbackGenerator: feedbackGenerator,
                                selectedDetail: $selectedDetail,
                                selectedItem: $selectedItem,
                                geometry: geometry,
                                colorScheme: colorScheme
                            )
                        }
                        
                        if recipe.imageremark?.isEmpty == false, let imageRemark = recipe.imageremark {
                            VStack(spacing: min(geometry.size.height * 0.01, 8)) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: min(geometry.size.width * 0.02, 8))
                                        .fill(Color(.systemGray5))
                                        .frame(width: min(geometry.size.width * 0.1, 40), height: min(geometry.size.width * 0.1, 40))
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            selectedItem == .imageremark
                                            ? RoundedRectangle(cornerRadius: min(geometry.size.width * 0.02, 8))
                                                .stroke(Color.primaryColor, lineWidth: 2)
                                                .shadow(radius: 4)
                                            : nil
                                        )
                                    if UIImage(named: imageRemark) != nil {
                                        Image(imageRemark)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: min(geometry.size.width * 0.06, 24), height: min(geometry.size.width * 0.06, 24))
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: min(geometry.size.width * 0.06, 24), height: min(geometry.size.width * 0.06, 24))
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
                            .padding(.top, min(geometry.size.height * 0.01, 8))
                        }
                        
                        if !recipe.category.isEmpty {
                            Text("Category: \(recipe.category)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.vertical, min(geometry.size.height * 0.015, 10))
                                .padding(.horizontal, min(geometry.size.width * 0.04, 16))
                                .background(
                                    Color(.systemGray5)
                                        .clipShape(RoundedRectangle(cornerRadius: min(geometry.size.width * 0.04, 16)))
                                )
                                .padding(.top, min(geometry.size.height * 0.02, 16))
                                .padding(.bottom, min(geometry.size.height * 0.02, 16))
                                .accessibilityLabel("Category: \(recipe.category)")
                        }
                    }
                    .padding(.vertical, min(geometry.size.height * 0.02, 16))
                }
                .safeAreaPadding(.bottom, 60)
                .accessibilityElement(children: .contain)
                .onAppear {
                    feedbackGenerator.prepare()
                    ingredientSets = computeIngredientSets()
                    outputs = computeOutputs()
                    print("RecipeDetailView: \(recipe.name), category: \(recipe.category), alternateIngredients: \(String(describing: recipe.alternateIngredients)), alternateOutput: \(String(describing: recipe.alternateOutput)), alternateIngredients1: \(String(describing: recipe.alternateIngredients1)), alternateOutput1: \(String(describing: recipe.alternateOutput1)), alternateIngredients2: \(String(describing: recipe.alternateIngredients2)), alternateOutput2: \(String(describing: recipe.alternateOutput2)), alternateIngredients3: \(String(describing: recipe.alternateIngredients3)), alternateOutput3: \(String(describing: recipe.alternateOutput3))")
                    print("RecipeDetailView bounds: \(UIScreen.main.bounds)")
                }
                .onChange(of: ingredientSets.count) { count in
                    print("Ingredient sets count: \(count)")
                }
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.large)
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
                            .foregroundColor(.primaryColor)
                            .font(.title2)
                            .scaleEffect(animateHeart ? 1.3 : 1.0)
                    }
                    .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
                    .accessibilityHint("Toggles favorite status for \(recipe.name)")
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
        }
    }
}

struct AlternateCraftingView: View {
    let ingredientSets: [[String]]
    @Binding var selectedCraftingOption: Int
    @Binding var selectedDetail: String?
    @Binding var craftingSelectedItem: RecipeDetailView.SelectedItem?
    let geometry: GeometryProxy
    let recipeName: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: min(geometry.size.width * 0.02, 8)) {
                ForEach(0..<ingredientSets.count, id: \.self) { index in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            selectedCraftingOption = index
                            selectedDetail = nil
                            craftingSelectedItem = nil
                        }
                    } label: {
                        Text("Recipe \(index + 1)")
                            .fontWeight(.bold)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Recipe \(index + 1)")
                    .accessibilityHint("Selects ingredient combination \(index + 1) for crafting \(recipeName)")
                }
            }
            .padding(.horizontal, min(geometry.size.width * 0.04, 16))
            .padding(.top, min(geometry.size.height * 0.01, 8))
        }
        .frame(maxWidth: .infinity, minHeight: min(geometry.size.height * 0.06, 44), maxHeight: min(geometry.size.height * 0.06, 44))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Crafting option picker")
        .accessibilityHint("Select different ingredient combinations for crafting \(recipeName)")
    }
}

struct DetailPopupView: View {
    let detail: String
    let selectedItem: RecipeDetailView.SelectedItem?
    let recipe: Recipe
    let feedbackGenerator: UIImpactFeedbackGenerator
    @Binding var selectedDetail: String?
    let geometry: GeometryProxy
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: min(geometry.size.height * 0.01, 8)) {
                DetailImageView(detail: detail, geometry: geometry)
                
                Text(detail)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, min(geometry.size.width * 0.02, 8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text(
                    selectedItem == .imageremark
                        ? (recipe.remarks?.isEmpty == false ? recipe.remarks! : "No remarks available")
                        : (detail == recipe.name ? "Output of crafting" : "Ingredient for \(recipe.name)")
                )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, min(geometry.size.width * 0.02, 8))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, min(geometry.size.height * 0.015, 12))
            .padding(.horizontal, min(geometry.size.width * 0.04, 16))
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color(.systemGray5)
                    RoundedRectangle(cornerRadius: min(geometry.size.width * 0.04, 16))
                        .stroke(Color.primaryColor, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: min(geometry.size.width * 0.04, 16)))
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
                    .foregroundColor(.primaryColor)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: min(geometry.size.width * 0.06, 24), height: min(geometry.size.width * 0.06, 24))
                            .shadow(radius: 2)
                    )
                    .frame(width: min(geometry.size.width * 0.06, 24), height: min(geometry.size.width * 0.06, 24))
            }
            .padding(.top, min(geometry.size.height * 0.005, 4))
            .padding(.trailing, min(geometry.size.width * 0.01, 4))
            .accessibilityLabel("Close popup")
            .accessibilityHint("Dismisses the details for \(detail)")
        }
        .padding(.horizontal, min(geometry.size.width * 0.04, 16))
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
}

struct DetailImageView: View {
    let detail: String
    let geometry: GeometryProxy
    
    var body: some View {
        Group {
            if UIImage(named: detail) != nil {
                Image(detail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(geometry.size.width * 0.2, 80), height: min(geometry.size.width * 0.2, 80))
                    .padding(min(geometry.size.width * 0.02, 8))
                    .background(Color(.systemGray5))
                    .cornerRadius(min(geometry.size.width * 0.03, 12))
                    .accessibilityLabel("Image of \(detail)")
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(geometry.size.width * 0.2, 80), height: min(geometry.size.width * 0.2, 80))
                    .padding(min(geometry.size.width * 0.02, 8))
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .cornerRadius(min(geometry.size.width * 0.03, 12))
                    .accessibilityLabel("Image unavailable for \(detail)")
            }
        }
    }
}

struct GridView: View {
    let recipe: Recipe
    @Binding var selectedItem: RecipeDetailView.SelectedItem?
    @Binding var selectedDetail: String?
    let ingredients: [String]
    let output: Int
    let geometry: GeometryProxy
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var craftingHeight: CGFloat { min(geometry.size.height * 0.3, 240) }
    private var cellSize: CGFloat { min(geometry.size.width * 0.15, 80) }
    private var gridWidth: CGFloat { cellSize * 3 + min(geometry.size.width * 0.015, 6) * 2 }
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: min(geometry.size.width * 0.04, 16)) {
                switch true {
                case recipe.imageremark == "Furnace":
                    VStack(spacing: min(geometry.size.height * 0.01, 6)) {
                        HStack {
                            Spacer()
                            GridCell(
                                index: 0,
                                ingredient: ingredients.count > 0 ? ingredients[0] : "",
                                isSelected: selectedItem == .grid(index: 0),
                                feedbackGenerator: feedbackGenerator,
                                cellSize: cellSize,
                                geometry: geometry
                            ) { selectedDetail = ingredients.count > 0 ? ingredients[0] : ""; selectedItem = .grid(index: 0) }
                            Spacer()
                        }
                        HStack {
                            Spacer()
                            Image(UIImage(named: "Furnace Fire") != nil ? "Furnace Fire" : "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: cellSize * 0.6, height: cellSize * 0.6)
                                .frame(width: cellSize, height: cellSize)
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
                                cellSize: cellSize,
                                geometry: geometry
                            ) { selectedDetail = ingredients.count > 1 ? ingredients[1] : ""; selectedItem = .grid(index: 1) }
                            Spacer()
                        }
                    }
                    .frame(width: gridWidth, height: craftingHeight)
                
                default:
                    VStack(spacing: min(geometry.size.height * 0.01, 6)) {
                        ForEach(0..<3) { row in
                            HStack(spacing: min(geometry.size.width * 0.015, 6)) {
                                ForEach(0..<3) { col in
                                    let index = row * 3 + col
                                    GridCell(
                                        index: index,
                                        ingredient: index < ingredients.count ? ingredients[index] : "",
                                        isSelected: selectedItem == .grid(index: index),
                                        feedbackGenerator: feedbackGenerator,
                                        cellSize: cellSize,
                                        geometry: geometry
                                    ) { selectedDetail = ingredients[index]; selectedItem = .grid(index: index) }
                                }
                            }
                        }
                    }
                    .frame(width: gridWidth, height: craftingHeight)
                }
                
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: min(geometry.size.width * 0.1, 40), height: craftingHeight)
                    .accessibilityHidden(true)
                
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: min(geometry.size.width * 0.03, 12))
                            .fill(Color(.systemGray5))
                            .frame(width: cellSize, height: cellSize)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .overlay(
                                selectedItem == .output
                                ? RoundedRectangle(cornerRadius: min(geometry.size.width * 0.03, 12))
                                    .stroke(Color.primaryColor, lineWidth: 2)
                                    .shadow(radius: 4)
                                : nil
                            )
                        
                        if UIImage(named: recipe.image) != nil {
                            Image(recipe.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: cellSize * 0.85, height: cellSize * 0.85)
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
            .padding(.horizontal, min(geometry.size.width * 0.04, 16))
        }
        .frame(height: craftingHeight)
        .animation(nil, value: selectedDetail)
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
    let geometry: GeometryProxy
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(geometry.size.width * 0.03, 12))
                .fill(!ingredient.isEmpty ? Color(.systemGray5) : Color(.systemGray6))
                .frame(width: cellSize, height: cellSize)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    isSelected
                    ? RoundedRectangle(cornerRadius: min(geometry.size.width * 0.03, 12))
                        .stroke(Color.primaryColor, lineWidth: 2)
                        .shadow(radius: 4)
                    : nil
                )
            
            if !ingredient.isEmpty {
                if UIImage(named: ingredient) != nil {
                    Image(ingredient)
                        .resizable()
                        .scaledToFit()
                        .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: cellSize * 0.85, height: cellSize * 0.85)
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
