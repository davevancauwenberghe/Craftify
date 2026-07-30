import SwiftUI

struct ChestsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenChestsTutorial") private var hasSeenTutorial = false
    @State private var navigationPath = NavigationPath()
    @State private var editor: ChestEditorContext?
    @State private var showTutorial = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if dataManager.chests.isEmpty {
                    ContentUnavailableView {
                        Label("Your Chest Room Is Empty", systemImage: "shippingbox")
                    } description: {
                        Text("Create a chest, then fill its slots with recipes you want to craft.")
                    } actions: {
                        Button("Create a Chest") { editor = .new }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(dataManager.chests) { chest in
                                NavigationLink(value: chest.id) {
                                    ChestRow(chest: chest)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        if let index = dataManager.chests.firstIndex(of: chest) {
                                            dataManager.deleteChests(at: IndexSet(integer: index))
                                            HapticFeedback.notification(.success)
                                        }
                                    }
                                    Button("Edit") { editor = .edit(chest) }
                                        .tint(Color.userAccentColor)
                                }
                                .contextMenu {
                                    Button("Edit Chest", systemImage: "pencil") { editor = .edit(chest) }
                                }
                            }
                            .onMove(perform: dataManager.moveChests)
                            .onDelete(perform: dataManager.deleteChests)
                        } header: {
                            Text("Drag in Edit mode to arrange your chest room")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chests")
            .navigationDestination(for: UUID.self) { id in
                if let chest = dataManager.chests.first(where: { $0.id == id }) {
                    ChestDetailView(chestID: chest.id, navigationPath: $navigationPath)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("About Chests", systemImage: "questionmark.circle") { showTutorial = true }
                    if !dataManager.chests.isEmpty { EditButton() }
                    Button("New Chest", systemImage: "plus") { editor = .new }
                }
            }
            .sheet(item: $editor) { context in
                ChestEditorView(context: context)
                    .environmentObject(dataManager)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showTutorial) {
                ChestsTutorialView()
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                dataManager.syncChests()
                if !hasSeenTutorial {
                    showTutorial = true
                    hasSeenTutorial = true
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: dataManager.chests)
        }
    }
}

private struct ChestRow: View {
    let chest: RecipeChest

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: chest.size == .large ? "shippingbox.fill" : "shippingbox")
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
        .accessibilityHint("Open chest")
    }
}

struct ChestDetailView: View {
    @EnvironmentObject private var dataManager: DataManager
    let chestID: UUID
    @Binding var navigationPath: NavigationPath
    @State private var editMode: EditMode = .inactive

    private var chest: RecipeChest? { dataManager.chests.first { $0.id == chestID } }

    var body: some View {
        Group {
            if let chest {
                let storedRecipes = dataManager.recipes(in: chest)
                List {
                    Section("\(storedRecipes.count) of \(chest.size.rawValue) slots used") {
                        ForEach(storedRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                HStack(spacing: 14) {
                                    Image(recipe.image).resizable().scaledToFit().frame(width: 44, height: 44)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading) {
                                        Text(recipe.name).font(.headline)
                                        Text(recipe.category).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            let recipeIDs = Set(offsets.compactMap { index in
                                storedRecipes.indices.contains(index) ? storedRecipes[index].id : nil
                            })
                            dataManager.removeRecipes(withIDs: recipeIDs, from: chestID)
                            HapticFeedback.impact()
                        }
                    }
                    if storedRecipes.isEmpty {
                        Text("Tap + on any recipe to place it in this chest.")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(chest.name)
                .toolbar { EditButton() }
                .environment(\.editMode, $editMode)
            } else {
                ContentUnavailableView("Chest Not Found", systemImage: "shippingbox")
            }
        }
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
        }
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
    let context: ChestEditorContext
    let recipeToAdd: Recipe?
    @State private var name: String
    @State private var size: RecipeChest.Size
    @State private var showShrinkConfirmation = false

    init(context: ChestEditorContext, recipeToAdd: Recipe? = nil) {
        self.context = context
        self.recipeToAdd = recipeToAdd
        if case .edit(let chest) = context {
            _name = State(initialValue: chest.name); _size = State(initialValue: chest.size)
        } else {
            _name = State(initialValue: ""); _size = State(initialValue: .small)
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
                }
                Section { Text("Java Edition chests use 27 slots for a small chest and 54 for a large chest.") }
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
            dataManager.createChest(name: name, size: size, adding: recipeToAdd)
        case .edit(let chest):
            guard dataManager.updateChest(
                chest,
                name: name,
                size: size,
                removingOverflow: removingOverflow
            ) else { return }
        }
        HapticFeedback.notification(.success)
        dismiss()
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
                    TutorialStep(icon: "arrow.up.arrow.down", title: "Make it yours", text: "Use Edit to rearrange chests. Swipe a chest to rename or delete it.")
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
