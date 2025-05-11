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
    
    private let craftingHeight: CGFloat = 222
    private let primaryColor = Color(hex: "00AA00")
    
    enum SelectedItem: Equatable {
        case grid(index: Int)
        case output
        case imageremark
    }
    
    private var allIngredientSets: [[String]] {
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
    
    private var allOutputs: [Int] {
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
    
    init(recipe: Recipe, navigationPath: Binding<NavigationPath>) {
        self.recipe = recipe
        self._navigationPath = navigationPath
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.shadowColor = nil
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().isTranslucent = false
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if allIngredientSets.count <= 1 {
                        Text("No alternate crafting options available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .accessibilityLabel("No alternate crafting options available for \(recipe.name)")
                    }
                    
                    if allIngredientSets.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<allIngredientSets.count, id: \.self) { index in
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
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCraftingOption == index ? primaryColor : Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .accessibilityLabel("Recipe \(index + 1)")
                                    .accessibilityHint("Selects ingredient combination \(index + 1) for crafting \(recipe.name)")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Crafting option picker")
                        .accessibilityHint("Select different ingredient combinations for crafting \(recipe.name)")
                    }
                    
                    GridView(
                        recipe: recipe,
                        selectedItem: $selectedItem,
                        selectedDetail: $selectedDetail,
                        craftingHeight: craftingHeight,
                        ingredients: allIngredientSets[selectedCraftingOption],
                        output: allOutputs[selectedCraftingOption]
                    )
                    
                    if let detail = selectedDetail {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 8) {
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
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                ZStack {
                                    Color(.systemGray5)
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(primaryColor, lineWidth: 2)
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
                                    .foregroundColor(primaryColor)
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
                        .padding(.horizontal, 16)
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
                    
                    if recipe.imageremark?.isEmpty == false {
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
                                                .stroke(primaryColor, lineWidth: 2)
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
                        .padding(.top, 8)
                    }
                    
                    if !recipe.category.isEmpty {
                        Text("Category: \(recipe.category)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                Color(.systemGray5)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            )
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                            .accessibilityLabel("Category: \(recipe.category)")
                    }
                }
                .padding(.vertical, 16)
            }
            .accessibilityElement(children: .contain)
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
                        .foregroundColor(primaryColor)
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
                .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
                .accessibilityHint("Toggles favorite status for \(recipe.name)")
            }
        }
        .onAppear {
            feedbackGenerator.prepare()
            print("RecipeDetailView: \(recipe.name), category: \(recipe.category), alternateIngredients: \(String(describing: recipe.alternateIngredients)), alternateOutput: \(String(describing: recipe.alternateOutput)), alternateIngredients1: \(String(describing: recipe.alternateIngredients1)), alternateOutput1: \(String(describing: recipe.alternateOutput1)), alternateIngredients2: \(String(describing: recipe.alternateIngredients2)), alternateOutput2: \(String(describing: recipe.alternateOutput2)), alternateIngredients3: \(String(describing: recipe.alternateIngredients3)), alternateOutput3: \(String(describing: recipe.alternateOutput3))")
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
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 16) {
                switch true {
                case recipe.imageremark == "Furnace":
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: 16)
                            GridCell(
                                index: 0,
                                ingredient: ingredients[0],
                                isSelected: selectedItem == .grid(index: 0),
                                feedbackGenerator: feedbackGenerator
                            ) { selectedDetail = ingredients[0]; selectedItem = .grid(index: 0) }
                            Spacer()
                        }
                        
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: 16)
                            Image(UIImage(named: "Furnace Fire") != nil ? "Furnace Fire" : "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .frame(width: 70, height: 70)
                            .accessibilityLabel("Furnace Fire slot")
                            .accessibilityHint("Represents the furnace in the crafting process")
                            Spacer()
                        }
                        
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: 16)
                            GridCell(
                                index: 1,
                                ingredient: ingredients[1],
                                isSelected: selectedItem == .grid(index: 1),
                                feedbackGenerator: feedbackGenerator
                            ) { selectedDetail = ingredients[1]; selectedItem = .grid(index: 1) }
                            Spacer()
                        }
                    }
                    .frame(height: craftingHeight)
                
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
                                        feedbackGenerator: feedbackGenerator
                                    ) { selectedDetail = ingredients[index]; selectedItem = .grid(index: index) }
                                }
                            }
                        }
                    }
                    .frame(height: craftingHeight)
                }
                
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: craftingHeight)
                    .accessibilityHidden(true)
                
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
                    Spacer()
                }
                .frame(height: craftingHeight)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, selectedDetail == nil ? 16 : 0)
            Spacer()
        }
        .frame(maxWidth: 360)
        .ignoresSafeArea(edges: .horizontal)
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
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(!ingredient.isEmpty ? Color(.systemGray5) : Color(.systemGray6))
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    isSelected
                    ? RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "00AA00"), lineWidth: 2)
                        .shadow(radius: 4)
                    : nil
                )
            
            if !ingredient.isEmpty {
                if UIImage(named: ingredient) != nil {
                    Image(ingredient)
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
