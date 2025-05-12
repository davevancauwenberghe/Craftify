//
//  RecipeDetailView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import CloudKit
#if os(macOS)
import AppKit
#endif

struct RecipeDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedDetail: String?
    @State private var selectedItem: SelectedItem?
    @State private var animateHeart: Bool = false
    @State private var selectedCraftingOption: Int = 0
    @State private var ingredientSets: [[String]] = []
    @State private var outputs: [Int] = []

    private let craftingHeight: CGFloat = 222
    private let primaryColor = Color(hex: "00AA00")

    enum SelectedItem: Equatable {
        case grid(index: Int)
        case output
        case imageremark
    }

    private func computeIngredientSets() -> [[String]] {
        let maxIngredients: Int = (recipe.imageremark == "Furnace") ? 2 : 9
        var sets: [[String]] = [recipe.ingredients]
        [recipe.alternateIngredients,
         recipe.alternateIngredients1,
         recipe.alternateIngredients2,
         recipe.alternateIngredients3]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .forEach { sets.append($0) }
        return sets.map { set in
            if set.count < maxIngredients {
                return set + Array(repeating: "", count: maxIngredients - set.count)
            } else {
                return Array(set.prefix(maxIngredients))
            }
        }
    }

    private func computeOutputs() -> [Int] {
        var outs = [recipe.output]
        if recipe.alternateIngredients != nil { outs.append(recipe.alternateOutput ?? recipe.output) }
        if recipe.alternateIngredients1 != nil { outs.append(recipe.alternateOutput1 ?? recipe.output) }
        if recipe.alternateIngredients2 != nil { outs.append(recipe.alternateOutput2 ?? recipe.output) }
        if recipe.alternateIngredients3 != nil { outs.append(recipe.alternateOutput3 ?? recipe.output) }
        return outs
    }

    var body: some View {
        ZStack {
            #if os(iOS)
            Color(.systemBackground)
            #else
            Color(NSColor.windowBackgroundColor)
            #endif
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Alternate crafting options
                    if ingredientSets.count <= 1 {
                        Text("No alternate crafting options available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    if ingredientSets.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<ingredientSets.count, id: \.self) { index in
                                    Button {
                                        #if os(iOS)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
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
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    // Crafting grid and output
                    GridView(
                        recipe: recipe,
                        selectedItem: $selectedItem,
                        selectedDetail: $selectedDetail,
                        craftingHeight: craftingHeight,
                        ingredients: ingredientSets.isEmpty ? [] : ingredientSets[selectedCraftingOption],
                        output: outputs.isEmpty ? recipe.output : outputs[selectedCraftingOption]
                    )

                    // Detail popup
                    if let detail = selectedDetail {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 8) {
                                Group {
                                    #if os(iOS)
                                    if UIImage(named: detail) != nil {
                                        Image(detail)
                                            .resizable()
                                    #else
                                    if NSImage(named: detail) != nil {
                                        Image(detail)
                                            .resizable()
                                    #endif
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .foregroundColor(.gray)
                                    }
                                }
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)

                                Text(detail)
                                    .font(.title2)
                                    .bold()
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)

                                Text(selectedItem == .imageremark
                                     ? (recipe.remarks?.isEmpty == false ? recipe.remarks! : "No remarks available")
                                     : (detail == recipe.name ? "Output of crafting" : "Ingredient for \(recipe.name)"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(primaryColor, lineWidth: 2)
                                    )
                                    .shadow(color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3), radius: 6)
                            )

                            Button {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    selectedDetail = nil
                                    selectedItem = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(primaryColor)
                                    .background(Circle().fill(Color.gray.opacity(0.1)))
                            }
                            .accessibilityLabel("Close")
                        }
                        .padding(.horizontal, 16)
                        .transition(.scale)
                    }

                    // Remark icon
                    if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                selectedDetail = imageRemark
                                selectedItem = .imageremark
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                #if os(iOS)
                                if UIImage(named: imageRemark) != nil {
                                    Image(imageRemark)
                                        .resizable()
                                #else
                                if NSImage(named: imageRemark) != nil {
                                    Image(imageRemark)
                                        .resizable()
                                #endif
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                            }
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        }
                        .padding(.top, 8)
                    }

                    // Category label
                    if !recipe.category.isEmpty {
                        Text("Category: \(recipe.category)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.1)))
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 50)
            }
            .accessibilityElement(children: .contain)
            .onAppear {
                ingredientSets = computeIngredientSets()
                outputs = computeOutputs()
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        animateHeart = true
                    }
                    dataManager.toggleFavorite(recipe: recipe)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        animateHeart = false
                    }
                } label: {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(primaryColor)
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                }
                .accessibilityLabel(dataManager.isFavorite(recipe: recipe) ? "Remove from favorites" : "Add to favorites")
            }
        }
    }
}

// MARK: - GridView

struct GridView: View {
    let recipe: Recipe
    @Binding var selectedItem: RecipeDetailView.SelectedItem?
    @Binding var selectedDetail: String?
    let craftingHeight: CGFloat
    let ingredients: [String]
    let output: Int

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                if recipe.imageremark == "Furnace" {
                    // Furnace layout
                    VStack {
                        ForEach([0,1], id: \.self) { idx in
                            GridCell(
                                index: idx,
                                ingredient: ingredients.indices.contains(idx) ? ingredients[idx] : "",
                                isSelected: selectedItem == .grid(index: idx)
                            ) {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                selectedDetail = ingredients.indices.contains(idx) ? ingredients[idx] : ""
                                selectedItem = .grid(index: idx)
                            }
                        }
                    }
                    .frame(width: 222, height: craftingHeight)
                } else {
                    // 3x3 grid
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row*3 + col
                                    GridCell(
                                        index: index,
                                        ingredient: ingredients.indices.contains(index) ? ingredients[index] : "",
                                        isSelected: selectedItem == .grid(index: index)
                                    ) {
                                        #if os(iOS)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
                                        selectedDetail = ingredients[index]
                                        selectedItem = .grid(index: index)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 222, height: craftingHeight)
                }

                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: craftingHeight)
                    .accessibilityHidden(true)

                // Output cell
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 70, height: 70)
                            .overlay(
                                selectedItem == .output ? RoundedRectangle(cornerRadius: 12).stroke(primaryColor, lineWidth: 2) : nil
                            )

                        if let imgName = recipe.image, !imgName.isEmpty {
                            Image(imgName)
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
                    .onTapGesture {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        selectedDetail = recipe.name
                        selectedItem = .output
                    }

                    Text("x\(output)")
                        .font(.headline)
                }
                .frame(height: craftingHeight)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .frame(height: craftingHeight)
    }
}

// MARK: - GridCell

struct GridCell: View {
    let index: Int
    let ingredient: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(ingredient.isEmpty ? Color.gray.opacity(0.05) : Color.gray.opacity(0.1))
                .frame(width: 70, height: 70)
                .overlay(
                    isSelected ? RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "00AA00"), lineWidth: 2) : nil
                )

            if !ingredient.isEmpty {
                Image(ingredient)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
        }
        .onTapGesture {
            guard !ingredient.isEmpty else { return }
            action()
        }
        .accessibilityLabel(ingredient.isEmpty ? "Empty slot" : "Ingredient: \(ingredient)")
    }
}

