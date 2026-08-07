//
//  RecipeDetailView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

enum SelectedItem: Equatable {
    case grid(index: Int)
    case output
}

struct RecipeDetailView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let recipe: Recipe
    @Binding var navigationPath: NavigationPath

    @State private var selectedDetail: String?
    @State private var selectedItem: SelectedItem?
    @State private var showingChestPicker = false
    @State private var selectedCraftingOption = 0
    @State private var ingredientSets: [[String]] = []
    @State private var outputs: [Int] = []

    private var currentIngredients: [String] {
        guard ingredientSets.indices.contains(selectedCraftingOption) else { return [] }
        return ingredientSets[selectedCraftingOption]
    }

    private var currentOutput: Int {
        guard outputs.indices.contains(selectedCraftingOption) else { return recipe.output }
        return outputs[selectedCraftingOption]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                RecipeIdentityHeader(recipe: recipe, output: currentOutput)

                AlternateRecipesSelector(
                    ingredientSets: ingredientSets,
                    selectedCraftingOption: $selectedCraftingOption,
                    selectedDetail: $selectedDetail,
                    selectedItem: $selectedItem
                )

                CraftingRecipeCard(
                    recipe: recipe,
                    ingredients: currentIngredients,
                    output: currentOutput,
                    selectedItem: $selectedItem,
                    selectedDetail: $selectedDetail
                )

                if let selectedDetail {
                    IngredientDetailPopup(
                        detail: selectedDetail,
                        selectedDetail: $selectedDetail,
                        selectedItem: $selectedItem,
                        navigationPath: $navigationPath
                    )
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity))
                }

                RemarkAndCategoryView(recipe: recipe)
            }
            .craftifyContentWidth()
            .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add to Chest", systemImage: "plus") {
                    HapticFeedback.impact()
                    showingChestPicker = true
                }
                .labelStyle(.iconOnly)
                .accessibilityHint("Opens your chests")
            }
        }
        .sheet(isPresented: $showingChestPicker) {
            AddRecipeToChestView(recipe: recipe)
                .environmentObject(dataManager)
        }
        .craftifyPage()
        .onAppear {
            ingredientSets = computeIngredientSets()
            outputs = computeOutputs()
        }
        .onChange(of: dataManager.isLoading) { _, isLoading in
            if !isLoading && dataManager.isManualSyncing { dataManager.syncChests() }
        }
        .animation(reduceMotion ? nil : .snappy, value: selectedDetail)
        .animation(reduceMotion ? nil : .snappy, value: selectedCraftingOption)
    }

    private func computeIngredientSets() -> [[String]] {
        let maximum = recipe.imageremark == "Furnace" ? 2 : 9
        let alternates = [
            recipe.alternateIngredients,
            recipe.alternateIngredients1,
            recipe.alternateIngredients2,
            recipe.alternateIngredients3
        ]
        let allSets = [recipe.ingredients] + alternates.compactMap { ingredients in
            guard let ingredients, !ingredients.isEmpty else { return nil }
            return ingredients
        }

        return allSets.map { ingredients in
            if ingredients.count < maximum {
                return ingredients + Array(repeating: "", count: maximum - ingredients.count)
            }
            return Array(ingredients.prefix(maximum))
        }
    }

    private func computeOutputs() -> [Int] {
        var result = [recipe.output]
        if recipe.alternateIngredients?.isEmpty == false { result.append(recipe.alternateOutput ?? recipe.output) }
        if recipe.alternateIngredients1?.isEmpty == false { result.append(recipe.alternateOutput1 ?? recipe.output) }
        if recipe.alternateIngredients2?.isEmpty == false { result.append(recipe.alternateOutput2 ?? recipe.output) }
        if recipe.alternateIngredients3?.isEmpty == false { result.append(recipe.alternateOutput3 ?? recipe.output) }
        return result
    }
}

private struct RecipeIdentityHeader: View {
    let recipe: Recipe
    let output: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) {
                    recipeImage
                    details(alignment: .center)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        recipeImage
                        details(alignment: .leading)
                    }
                    VStack(spacing: 16) {
                        recipeImage
                        details(alignment: .center)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .craftifyCard(cornerRadius: 26)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.category), crafting output \(output)")
    }

    private var recipeImage: some View {
        ZStack {
            AppBackground()
            CraftImage(key: recipe.image)
                .scaledToFit()
                .padding(16)
        }
        .frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func details(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 7) {
            Text("CRAFTING RECIPE")
                .font(.caption.bold())
                .tracking(1.1)
                .foregroundStyle(accent)
            Text(recipe.name)
                .font(.largeTitle.bold())
                .multilineTextAlignment(alignment)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { metadata }
                VStack(alignment: alignment == .center ? .center : .leading, spacing: 8) { metadata }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    @ViewBuilder
    private var metadata: some View {
        if !recipe.category.isEmpty {
            CraftifyStatusPill(title: recipe.category, symbol: "tag.fill")
        }
        CraftifyStatusPill(title: "Makes \(output)", symbol: "shippingbox.fill")
    }
}

private struct AddRecipeToChestView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.craftifyAccentColor) private var accent
    let recipe: Recipe
    @State private var creatingChest = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Create New Chest", systemImage: "plus.rectangle.on.folder") {
                        creatingChest = true
                    }
                    .fontWeight(.semibold)
                }

                if !dataManager.chests.isEmpty {
                    Section("Choose a Chest") {
                        ForEach(dataManager.chests) { chest in
                            Button {
                                add(to: chest)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: chest.displaySymbol)
                                        .foregroundStyle(accent)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(chest.name).foregroundStyle(.primary)
                                        ProgressView(
                                            value: Double(chest.recipeIDs.count),
                                            total: Double(chest.size.rawValue)
                                        )
                                        .tint(accent)
                                    }
                                    Text("\(chest.recipeIDs.count)/\(chest.size.rawValue)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(chest.recipeIDs.count >= chest.size.rawValue || chest.recipeIDs.contains(recipe.id))
                            .accessibilityHint(chest.recipeIDs.contains(recipe.id) ? "Recipe already stored here" : "Adds recipe to this chest")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Store \(recipe.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $creatingChest) {
                ChestEditorView(context: .new, recipeToAdd: recipe) {
                    creatingChest = false
                    dismiss()
                }
                .environmentObject(dataManager)
                .presentationDetents([.medium])
                .presentationSizing(.page)
            }
            .alert("Couldn’t Add Recipe", isPresented: messageBinding) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "Please try another chest.")
            }
            .craftifyPage()
        }
        .presentationDetents([.medium, .large])
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private func add(to chest: RecipeChest) {
        if dataManager.add(recipe, to: chest) {
            HapticFeedback.notification(.success)
            dismiss()
        } else {
            HapticFeedback.notification(.warning)
            message = chest.recipeIDs.contains(recipe.id)
                ? "This recipe is already in \(chest.name)."
                : "\(chest.name) is full."
        }
    }
}

struct AlternateRecipesSelector: View {
    let ingredientSets: [[String]]
    @Binding var selectedCraftingOption: Int
    @Binding var selectedDetail: String?
    @Binding var selectedItem: SelectedItem?
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        if ingredientSets.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                CraftifySectionHeader(
                    title: "Crafting Options",
                    detail: "Choose an ingredient combination."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ingredientSets.indices, id: \.self) { index in
                            let isSelected = selectedCraftingOption == index
                            Button("Option \(index + 1)") {
                                selectedCraftingOption = index
                                selectedDetail = nil
                                selectedItem = nil
                                HapticFeedback.selection()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? accent : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                            .buttonStyle(.plain)
                            .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(18)
            .craftifyCard(cornerRadius: 22)
        }
    }
}

private struct CraftingRecipeCard: View {
    let recipe: Recipe
    let ingredients: [String]
    let output: Int
    @Binding var selectedItem: SelectedItem?
    @Binding var selectedDetail: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    private var cellSize: CGFloat {
        horizontalSizeClass == .regular ? 76 : 64
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CraftifySectionHeader(
                title: recipe.imageremark == "Furnace" ? "Smelting Layout" : "Crafting Layout",
                detail: "Tap an ingredient or the output to inspect it.",
                symbol: recipe.imageremark == "Furnace" ? "flame.fill" : "square.grid.3x3.fill"
            )

            if dynamicTypeSize.isAccessibilitySize {
                verticalLayout
            } else {
                ViewThatFits(in: .horizontal) {
                    horizontalLayout
                    verticalLayout
                }
            }
        }
        .padding(20)
        .craftifyCard(cornerRadius: 24)
    }

    private var horizontalLayout: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 28 : 20) {
            craftingGrid
            Image(systemName: "arrow.right")
                .font(.title.bold())
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            outputTile
        }
        .frame(maxWidth: .infinity)
    }

    private var verticalLayout: some View {
        VStack(spacing: 15) {
            craftingGrid
            Image(systemName: "arrow.down")
                .font(.title2.bold())
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            outputTile
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var craftingGrid: some View {
        if recipe.imageremark == "Furnace" {
            FurnaceGridView(
                ingredients: ingredients,
                selectedItem: $selectedItem,
                selectedDetail: $selectedDetail,
                cellSize: cellSize
            )
        } else {
            DefaultGridView(
                ingredients: ingredients,
                selectedItem: $selectedItem,
                selectedDetail: $selectedDetail,
                cellSize: cellSize
            )
        }
    }

    private var outputTile: some View {
        Button {
            selectedDetail = recipe.name
            selectedItem = .output
            HapticFeedback.impact()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(accent.opacity(0.09))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(
                                    selectedItem == .output ? accent : accent.opacity(0.18),
                                    lineWidth: selectedItem == .output ? 2 : 1
                                )
                        }
                    CraftImage(key: recipe.image)
                        .scaledToFit()
                        .padding(9)
                }
                .frame(width: cellSize + 12, height: cellSize + 12)

                Text("×\(output)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Output: \(recipe.name), quantity \(output)")
        .accessibilityHint("Shows output details")
    }
}

struct IngredientDetailPopup: View {
    let detail: String
    @Binding var selectedDetail: String?
    @Binding var selectedItem: SelectedItem?
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    private var subRecipe: Recipe? {
        guard case .grid(_) = selectedItem else { return nil }
        return dataManager.recipes.first { $0.name == detail }
    }

    private var descriptor: String {
        switch selectedItem {
        case .output: "Crafting output"
        case .grid: "Crafting ingredient"
        case nil: "Recipe detail"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text(descriptor.uppercased())
                    .font(.caption.bold())
                    .tracking(1)
                    .foregroundStyle(accent)

                Spacer(minLength: 8)

                Button("Close", systemImage: "xmark.circle.fill") {
                    selectedDetail = nil
                    selectedItem = nil
                    HapticFeedback.impact(.light)
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .accessibilityHint("Dismisses these details")
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 14) {
                        detailImage
                        detailTitle
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 16) {
                            detailImage
                            detailTitle
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            detailImage
                            detailTitle
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let subRecipe {
                Button {
                    navigationPath.append(subRecipe)
                } label: {
                    Label("View \(subRecipe.name) Recipe", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .craftifyButtonBorder(cornerRadius: 16)
            }
        }
        .padding(18)
        .craftifyCard(cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }

    private var detailImage: some View {
        CraftImage(key: detail)
            .scaledToFit()
            .frame(width: 76, height: 76)
            .padding(8)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }

    private var detailTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(detail)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(selectedItem == .output ? "The item produced by this recipe." : "An item required in the crafting layout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RemarkAndCategoryView: View {
    let recipe: Recipe
    @Environment(\.craftifyAccentColor) private var accent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isUtilityExpanded = false

    var body: some View {
        if recipe.imageremark?.isEmpty == false || recipe.remarks?.isEmpty == false {
            VStack(alignment: .leading, spacing: 15) {
                CraftifySectionHeader(
                    title: "Crafting Notes",
                    detail: "Extra context for this recipe.",
                    symbol: "lightbulb.fill"
                )

                if let imageRemark = recipe.imageremark, !imageRemark.isEmpty {
                    DisclosureGroup(isExpanded: $isUtilityExpanded) {
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 12) {
                                    utilityImage(imageRemark)
                                    utilityCopy(imageRemark)
                                }
                            } else {
                                HStack(alignment: .top, spacing: 14) {
                                    utilityImage(imageRemark)
                                    utilityCopy(imageRemark)
                                }
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: "hammer.fill")
                                .font(.headline)
                                .foregroundStyle(accent)
                                .frame(width: 40, height: 40)
                                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Required Crafting Utility")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(isUtilityExpanded ? "Hide utility details" : "Show utility details")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(accent)
                    .onChange(of: isUtilityExpanded) { _, _ in HapticFeedback.selection() }
                    .accessibilityHint("Shows the required utility and crafting notes")
                }

                if recipe.imageremark?.isEmpty != false,
                   let remarks = recipe.remarks,
                   !remarks.isEmpty {
                    Text(remarks)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .craftifyCard(cornerRadius: 22)
        }
    }

    private func utilityImage(_ imageRemark: String) -> some View {
        CraftImage(key: imageRemark)
            .scaledToFit()
            .frame(width: 64, height: 64)
            .padding(7)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
    }

    private func utilityCopy(_ imageRemark: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(imageRemark)
                .font(.headline)
            Text("Use this utility for the crafting layout shown above.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let remarks = recipe.remarks, !remarks.isEmpty {
                Text(remarks)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }
}

struct FurnaceGridView: View {
    let ingredients: [String]
    @Binding var selectedItem: SelectedItem?
    @Binding var selectedDetail: String?
    let cellSize: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            ingredientCell(index: 0)
            Image("Furnace Fire")
                .resizable()
                .scaledToFit()
                .padding(cellSize * 0.28)
                .frame(width: cellSize, height: cellSize)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Furnace fire")
            ingredientCell(index: 1)
        }
    }

    private func ingredientCell(index: Int) -> some View {
        GridCell(
            index: index,
            ingredient: ingredients.indices.contains(index) ? ingredients[index] : "",
            isSelected: selectedItem == .grid(index: index),
            cellSize: cellSize
        ) {
            selectedDetail = ingredients[index]
            selectedItem = .grid(index: index)
        }
    }
}

struct DefaultGridView: View {
    let ingredients: [String]
    @Binding var selectedItem: SelectedItem?
    @Binding var selectedDetail: String?
    let cellSize: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<3) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3) { column in
                        let index = row * 3 + column
                        GridCell(
                            index: index,
                            ingredient: ingredients.indices.contains(index) ? ingredients[index] : "",
                            isSelected: selectedItem == .grid(index: index),
                            cellSize: cellSize
                        ) {
                            selectedDetail = ingredients[index]
                            selectedItem = .grid(index: index)
                        }
                    }
                }
            }
        }
    }
}

struct GridCell: View {
    let index: Int
    let ingredient: String
    let isSelected: Bool
    let cellSize: CGFloat
    let onTap: () -> Void
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        Button {
            guard !ingredient.isEmpty else { return }
            HapticFeedback.impact()
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ingredient.isEmpty ? Color.primary.opacity(0.035) : accent.opacity(0.075))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? accent : Color.primary.opacity(ingredient.isEmpty ? 0.05 : 0.10),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                if !ingredient.isEmpty {
                    CraftImage(key: ingredient)
                        .scaledToFit()
                        .padding(7)
                }
            }
            .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.plain)
        .disabled(ingredient.isEmpty)
        .accessibilityLabel(ingredient.isEmpty ? "Empty crafting slot" : "Ingredient: \(ingredient)")
        .accessibilityHint(ingredient.isEmpty ? "" : "Shows ingredient details")
    }
}
