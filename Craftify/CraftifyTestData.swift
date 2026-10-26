#if DEBUG
    import Foundation

    /// A deterministic offline library for simulator UI tests. Release builds omit it.
    enum CraftifyTestData {
        @MainActor
        static func makeDataManager() -> DataManager {
            let defaults = UserDefaults(suiteName: "Craftify.UITests")!
            defaults.removePersistentDomain(forName: "Craftify.UITests")
            let manager = DataManager(keyValueStore: defaults, defaults: defaults, startsServices: false)
            manager.recipes = [
                recipe(1, "Crafting Table", ingredients: ["Oak Planks", "Oak Planks", "", "Oak Planks", "Oak Planks"]),
                recipe(
                    2, "Stick", ingredients: ["Oak Planks", "", "", "Oak Planks"],
                    alternate: ["Spruce Planks", "", "", "Spruce Planks"], output: 4),
                recipe(3, "Oak Planks", ingredients: ["Oak Log"], output: 4),
                recipe(4, "Stone Button", ingredients: ["Stone"]),
                recipe(
                    5, "Furnace",
                    ingredients: [
                        "Cobblestone", "Cobblestone", "Cobblestone", "Cobblestone", "", "Cobblestone", "Cobblestone",
                        "Cobblestone", "Cobblestone",
                    ]),
            ]
            manager.createChest(name: "Starter Build", size: .small, adding: manager.recipes[0])
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-filled-chest"),
            let chest = manager.chests.first
        {
            for recipe in manager.recipes.dropFirst() { _ = manager.add(recipe, to: chest) }
        }
            return manager
        }

        private static func recipe(
            _ id: Int, _ name: String, ingredients: [String], alternate: [String]? = nil, output: Int = 1
        ) -> Recipe {
            Recipe(
                id: id, name: name, image: name, ingredients: ingredients,
                alternateIngredients: nil, alternateIngredients1: alternate,
                alternateIngredients2: nil, alternateIngredients3: nil,
                output: output, alternateOutput: nil, alternateOutput1: nil,
                alternateOutput2: nil, alternateOutput3: nil,
                category: "Utility", imageremark: nil, remarks: nil
            )
        }
    }
#endif
