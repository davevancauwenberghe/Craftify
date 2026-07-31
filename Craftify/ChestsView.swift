//
//  ChestsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 30/07/2026.
//

import SwiftUI

struct ChestsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @AppStorage("hasSeenChestsTutorial") private var hasSeenTutorial = false
    @State private var navigationPath = NavigationPath()
    @State private var editor: ChestEditorContext?
    @State private var showTutorial = false
    @State private var chestPendingDeletion: RecipeChest?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if dataManager.chests.isEmpty {
                    ContentUnavailableView {
                        Label("Your Chest Room Is Empty", systemImage: "shippingbox")
                    } description: {
                        Text("Create a chest, then fill its slots with recipes you want to craft.")
                    } actions: {
                        Button("Create a Chest") {
                            HapticFeedback.impact()
                            editor = .new
                        }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(dataManager.chests) { chest in
                                ChestListRow(
                                    chest: chest,
                                    isEditing: editMode.isEditing,
                                    onEdit: { editor = .edit(chest) },
                                    onDelete: { chestPendingDeletion = chest }
                                )
                            }
                            .onMove(perform: dataManager.moveChests)
                            .onDelete { offsets in
                                if let index = offsets.first, dataManager.chests.indices.contains(index) {
                                    chestPendingDeletion = dataManager.chests[index]
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .id(accentColorPreference)
            .tint(Color.userAccentColor)
            .navigationTitle("Chests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let chest = dataManager.chests.first(where: { $0.id == id }) {
                    ChestDetailView(chestID: chest.id, navigationPath: $navigationPath)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("About Chests", systemImage: "questionmark.circle") {
                        HapticFeedback.impact()
                        showTutorial = true
                    }
                    if !dataManager.chests.isEmpty {
                        Button(editMode.isEditing ? "Done" : "Edit", action: toggleEditMode)
                    }
                    Button("New Chest", systemImage: "plus") {
                        HapticFeedback.impact()
                        editor = .new
                    }
                }
            }
            .sheet(item: $editor) { context in
                ChestEditorView(context: context)
                    .environmentObject(dataManager)
                    .presentationDetents([.medium])
                    .presentationSizing(.page)
            }
            .sheet(isPresented: $showTutorial) {
                tutorialSheet
            }
            .alert("Delete \(pendingChestName)?", isPresented: isShowingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { chestPendingDeletion = nil }
                Button("Delete Chest", role: .destructive) { deletePendingChest() }
            } message: {
                Text("This permanently removes the chest and its stored recipe list from iCloud.")
            }
            .onAppear {
                dataManager.syncChests()
                if !hasSeenTutorial {
                    showTutorial = true
                    hasSeenTutorial = true
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: dataManager.chests)
            .environment(\.editMode, $editMode)
        }
    }

    private var pendingChestName: String {
        chestPendingDeletion?.name ?? "chest"
    }

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { chestPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    chestPendingDeletion = nil
                }
            }
        )
    }

    /// The presentation sizing styles have different concrete types. Keeping
    /// them in separate result-builder branches avoids asking the compiler to
    /// infer a common type for `.form` and `.page` in a ternary expression.
    @ViewBuilder
    private var tutorialSheet: some View {
        if horizontalSizeClass == .regular {
            ChestsTutorialView()
                .presentationDetents([.medium, .large])
                .presentationSizing(.form)
        } else {
            ChestsTutorialView()
                .presentationDetents([.medium, .large])
                .presentationSizing(.page)
        }
    }

    private func deletePendingChest() {
        guard let chest = chestPendingDeletion,
              let index = dataManager.chests.firstIndex(where: { $0.id == chest.id }) else { return }
        dataManager.deleteChests(at: IndexSet(integer: index))
        chestPendingDeletion = nil
        HapticFeedback.notification(.success)
    }

    private func toggleEditMode() {
        HapticFeedback.impact()
        let animation: Animation? = reduceMotion ? nil : Animation.default
        let nextEditMode: EditMode = editMode.isEditing ? .inactive : .active
        withAnimation(animation) {
            editMode = nextEditMode
        }
    }
}

private struct ChestListRow: View {
    let chest: RecipeChest
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        rowContent
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive, action: onDelete)
                    .tint(.red)
                Button("Edit", action: onEdit)
                    .tint(Color.userAccentColor)
            }
            .contextMenu {
                Button("Edit Chest", systemImage: "pencil", action: onEdit)
                Button("Delete Chest", systemImage: "trash", role: .destructive, action: onDelete)
            }
    }

    @ViewBuilder
    private var rowContent: some View {
        if isEditing {
            Button(action: onEdit) {
                ChestRow(chest: chest)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: chest.id) {
                ChestRow(chest: chest)
            }
        }
    }
}

private struct ChestRow: View {
    let chest: RecipeChest

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: chest.displaySymbol)
                .font(.title2)
                .foregroundStyle(Color.userAccentColor)
                .frame(width: 44, height: 44)
                .background(Color.userAccentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(chest.name).font(.headline)
                Text("\(chest.recipeIDs.count) of \(chest.size.rawValue) slots")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value: Double(chest.recipeIDs.count), total: Double(chest.size.rawValue))
                    .tint(Color.userAccentColor)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chest.name), \(chest.size.title), \(chest.recipeIDs.count) of \(chest.size.rawValue) slots used")
        .accessibilityHint("Opens the chest")
    }
}

struct ChestDetailView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    let chestID: UUID
    @Binding var navigationPath: NavigationPath
    @State private var editMode: EditMode = .inactive
    @State private var chestName = ""

    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var pagePadding: CGFloat = 16

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        // An adaptive grid keeps cards comfortably readable on iPhone while
        // using the additional width available on iPad and in landscape.
        return [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: cardSpacing)]
    }

    private var chest: RecipeChest? { dataManager.chests.first { $0.id == chestID } }

    var body: some View {
        Group {
            if let chest {
                let storedRecipes = dataManager.recipes(in: chest)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ChestDetailHeader(
                            chest: chest,
                            usedSlots: storedRecipes.count,
                            isEditing: editMode.isEditing,
                            name: $chestName
                        )
                        if storedRecipes.isEmpty {
                            ContentUnavailableView {
                                Label("No Stored Recipes", systemImage: "square.grid.3x3")
                            } description: {
                                Text("Open a recipe and use the add button to store it in this chest.")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Stored Recipes")
                                    .font(.title2.bold())
                                    .accessibilityAddTraits(.isHeader)

                                LazyVGrid(columns: gridColumns, spacing: cardSpacing) {
                                    ForEach(Array(storedRecipes.enumerated()), id: \.element.id) { slot, recipe in
                                        ZStack(alignment: .topTrailing) {
                                            NavigationLink(value: recipe) {
                                                ChestRecipeCard(recipe: recipe, slot: slot + 1)
                                            }
                                            .buttonStyle(.plain)

                                            if editMode.isEditing {
                                                Button("Remove \(recipe.name)", systemImage: "minus.circle.fill") {
                                                    dataManager.removeRecipes(withIDs: [recipe.id], from: chestID)
                                                    HapticFeedback.impact()
                                                }
                                                .labelStyle(.iconOnly)
                                                .font(.title2)
                                                .foregroundStyle(.white, .red)
                                                .frame(minWidth: 44, minHeight: 44)
                                                .contentShape(Rectangle())
                                                .accessibilityHint("Removes this recipe from \(chest.name)")
                                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 1200)
                    .padding(pagePadding)
                    .frame(maxWidth: .infinity)
                }
                .background {
                    ChestDetailBackground()
                        .ignoresSafeArea()
                }
                .id(accentColorPreference).tint(Color.userAccentColor)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    Button(editMode.isEditing ? "Done" : "Edit", action: toggleEditMode)
                }
                .environment(\.editMode, $editMode)
                .onAppear {
                    if !editMode.isEditing {
                        chestName = chest.name
                    }
                }
                .onChange(of: chest.name) { _, newName in
                    if !editMode.isEditing { chestName = newName }
                }
            } else {
                ContentUnavailableView("Chest Not Found", systemImage: "shippingbox")
            }
        }
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
        }
    }

    private func toggleEditMode() {
        HapticFeedback.impact()
        if editMode.isEditing, let chest {
            let cleanedName = chestName.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedName.isEmpty {
                chestName = chest.name
            } else if cleanedName != chest.name {
                _ = dataManager.updateChest(
                    chest,
                    name: cleanedName,
                    size: chest.size,
                    symbol: chest.symbol
                )
                chestName = cleanedName
                HapticFeedback.notification(.success)
            }
        }
        let animation: Animation? = reduceMotion ? nil : Animation.snappy
        let nextEditMode: EditMode = editMode.isEditing ? .inactive : .active
        withAnimation(animation) {
            editMode = nextEditMode
        }
    }
}

private struct ChestDetailHeader: View {
    let chest: RecipeChest
    let usedSlots: Int
    let isEditing: Bool
    @Binding var name: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                chestIcon
                details(centered: false)
            }

            VStack(spacing: 16) {
                chestIcon
                details(centered: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: isEditing ? .contain : .combine)
        .accessibilityLabel(isEditing ? "Chest details" : "\(chest.name), \(usedSlots) of \(chest.size.rawValue) slots used")
    }

    private var chestIcon: some View {
        Image(systemName: chest.displaySymbol)
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(Color.userAccentColor.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.userAccentColor.opacity(0.25), radius: 14, y: 8)
            .accessibilityHidden(true)
    }

    private func details(centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 10) {
            if isEditing {
                TextField("Chest name", text: $name)
                    .font(.title.bold())
                    .multilineTextAlignment(centered ? .center : .leading)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxWidth: 400)
            } else {
                Text(chest.name)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(centered ? .center : .leading)
            }

            Label("\(usedSlots) of \(chest.size.rawValue) slots used", systemImage: "square.grid.3x3.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(usedSlots), total: Double(chest.size.rawValue))
                .tint(Color.userAccentColor)
                .frame(maxWidth: 400)
                .accessibilityLabel("Chest capacity")
                .accessibilityValue("\(usedSlots) of \(chest.size.rawValue) slots used")
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

private struct ChestDetailBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.userAccentColor.opacity(0.20),
                    Color.userAccentColor.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ChestRecipeCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let recipe: Recipe
    let slot: Int
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color(.systemBackground)
                Image(recipe.image)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                Text("\(slot)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .aspectRatio(1.35, contentMode: .fit)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.name).font(.headline).foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Label(recipe.category, systemImage: "tag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.userAccentColor)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.userAccentColor.opacity(0.4), lineWidth: 1) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Slot \(slot), \(recipe.name), \(recipe.category)")
        .accessibilityHint("Opens recipe details")
    }
}

enum ChestEditorContext: Identifiable {
    case new
    case edit(RecipeChest)
    var id: String { switch self { case .new: "new"; case .edit(let chest): chest.id.uuidString } }
}

struct ChestEditorView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    let context: ChestEditorContext
    let recipeToAdd: Recipe?
    let onSave: (() -> Void)?
    @State private var name: String
    @State private var size: RecipeChest.Size
    @State private var symbol: String?
    @State private var showShrinkConfirmation = false

    init(context: ChestEditorContext, recipeToAdd: Recipe? = nil, onSave: (() -> Void)? = nil) {
        self.context = context
        self.recipeToAdd = recipeToAdd
        self.onSave = onSave
        if case .edit(let chest) = context {
            _name = State(initialValue: chest.name); _size = State(initialValue: chest.size); _symbol = State(initialValue: chest.symbol)
        } else {
            _name = State(initialValue: ""); _size = State(initialValue: .small); _symbol = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chest details") {
                    TextField("Chest name", text: $name).textInputAutocapitalization(.words)
                    Picker("Capacity", selection: $size) {
                        ForEach(RecipeChest.Size.allCases) { size in
                            Text("\(size.title) · \(size.rawValue) slots").tag(size)
                        }
                    }
                    Picker("Symbol", selection: $symbol) {
                        Label("Automatic", systemImage: size == .large ? "shippingbox.fill" : "shippingbox").tag(String?.none)
                        ForEach(Self.symbols, id: \.self) { symbol in
                            Label(Self.symbolName(symbol), systemImage: symbol).tag(Optional(symbol))
                        }
                    }
                }
            }
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if overflowCount > 0 {
                            showShrinkConfirmation = true
                        } else {
                            saveChanges()
                        }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Remove \(overflowCount) stored recipes?", isPresented: $showShrinkConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Shrink Chest", role: .destructive) { saveChanges(removingOverflow: true) }
            } message: {
                Text("A small chest holds 27 recipes. Shrinking will permanently remove the last \(overflowCount) recipes from this chest and sync the change to iCloud.")
            }
            .id(accentColorPreference)
            .tint(Color.userAccentColor)
        }
    }

    private var overflowCount: Int {
        guard case .edit(let chest) = context else { return 0 }
        let storedCount = dataManager.chests.first(where: { $0.id == chest.id })?.recipeIDs.count ?? chest.recipeIDs.count
        return max(0, storedCount - size.rawValue)
    }

    private func saveChanges(removingOverflow: Bool = false) {
        switch context {
        case .new:
            dataManager.createChest(name: name, size: size, symbol: symbol, adding: recipeToAdd)
        case .edit(let chest):
            guard dataManager.updateChest(
                chest,
                name: name,
                size: size,
                symbol: symbol,
                removingOverflow: removingOverflow
            ) else { return }
        }
        HapticFeedback.notification(.success)
        dismiss()
        onSave?()
    }

    private static let symbols = ["archivebox.fill", "cube.fill", "shippingbox.and.arrow.backward.fill", "backpack.fill", "square.grid.3x3.fill", "building.columns.fill", "mountain.2.fill", "flame.fill", "diamond.fill", "hammer.fill"]

    private static func symbolName(_ symbol: String) -> String {
        ["archivebox.fill": "Storage", "cube.fill": "Block", "shippingbox.and.arrow.backward.fill": "Delivery", "backpack.fill": "Inventory", "square.grid.3x3.fill": "Crafting Grid", "building.columns.fill": "Stronghold", "mountain.2.fill": "Mountains", "flame.fill": "Nether", "diamond.fill": "Diamond", "hammer.fill": "Tools"][symbol] ?? symbol
    }
}

private extension ChestEditorContext {
    var title: String { switch self { case .new: "New Chest"; case .edit: "Edit Chest" } }
}

struct ChestsTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Welcome to Chests", systemImage: "shippingbox.fill")
                        .font(.largeTitle.bold()).foregroundStyle(Color.userAccentColor)
                    TutorialStep(icon: "plus.circle.fill", title: "Collect recipes", text: "Tap + on a recipe and choose a chest, or create one without leaving the recipe.")
                    TutorialStep(icon: "square.grid.3x3.fill", title: "Minecraft-sized storage", text: "Small chests hold 27 recipes. Large chests hold 54, just like Java Edition.")
                    TutorialStep(icon: "paintpalette.fill", title: "Make it yours", text: "Give every chest a name and a Minecraft-inspired symbol that fits what you store.")
                    TutorialStep(icon: "arrow.up.arrow.down", title: "Arrange safely", text: "Use Edit to drag chests into order, or tap one to change its name, size, or symbol. Swipe for Edit and a confirmed Delete.")
                    Text("Your chest room syncs through iCloud, so its order, names, and recipes follow you across devices.")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(24)
            }
            .toolbar { Button("Done") { dismiss() }.fontWeight(.semibold) }
        }
    }
}

private struct TutorialStep: View {
    let icon: String; let title: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.userAccentColor).frame(width: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
