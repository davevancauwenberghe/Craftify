//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import Combine
import CloudKit

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var favorites: [Recipe] = []
    @Published var selectedCategory: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var cacheClearedMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var accessibilityAnnouncement: String? = nil

    private let iCloudKey = "favoriteRecipes"
    private var cancellables = Set<AnyCancellable>()

    enum ErrorType: String {
        case network = "Network issue, please check your connection and try again."
        case permissions = "Permission denied, please enable iCloud access."
        case dataCorruption = "Data error, please try refreshing."
        case unknown = "An unexpected error occurred."
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        // Clear error messages after 5 seconds
        $errorMessage
            .sink { [weak self] message in
                if message != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self?.errorMessage = nil
                    }
                }
            }
            .store(in: &cancellables)

        $cacheClearedMessage
            .sink { [weak self] message in
                if let message = message {
                    self?.accessibilityAnnouncement = message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self?.cacheClearedMessage = nil
                        self?.accessibilityAnnouncement = nil
                    }
                }
            }
            .store(in: &cancellables)

        // Load from local cache first
        if let localRecipes = loadRecipesFromLocalCache() {
            print("Loaded \(localRecipes.count) recipes from local cache.")
            self.recipes = localRecipes.sorted(by: { $0.name < $1.name })
            self.syncFavorites()
        } else {
            print("No local cache found; will fetch from CloudKit.")
        }

        // Then fetch from CloudKit
        loadData {
            self.syncFavorites()
        }
    }

    // MARK: - Sync Status

    var syncStatus: String {
        if let lastUpdated = lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "Last synced: \(formatter.string(from: lastUpdated))"
        } else if isLoading {
            return "Syncing recipes..."
        } else if let error = errorMessage {
            return "Sync failed: \(error)"
        } else {
            return "Not synced"
        }
    }

    // MARK: - Favorite Handling

    func isFavorite(recipe: Recipe) -> Bool {
        return favorites.contains { $0.id == recipe.id }
    }

    func toggleFavorite(recipe: Recipe) {
        if let index = favorites.firstIndex(where: { $0.id == recipe.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(recipe)
        }
        saveFavorites()
    }

    func saveFavorites() {
        let favoriteIDs = favorites.map { $0.id }
        NSUbiquitousKeyValueStore.default.set(favoriteIDs, forKey: iCloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func syncFavorites() {
        if let savedIDs = NSUbiquitousKeyValueStore.default.array(forKey: iCloudKey) as? [Int] {
            // Validate favorite IDs against available recipes
            let validIDs = savedIDs.filter { id in recipes.contains { $0.id == id } }
            favorites = recipes.filter { validIDs.contains($0.id) }
            if validIDs.count < savedIDs.count {
                // Clean up invalid IDs
                NSUbiquitousKeyValueStore.default.set(validIDs, forKey: iCloudKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            }
        }
    }

    @objc private func icloudDidChange() {
        syncFavorites()
    }

    // MARK: - CloudKit & Local File Caching

    func loadData(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        
        var fetchedRecipes: [Recipe] = []

        // Recursive function to fetch records with a given query operation
        func fetch(with queryOperation: CKQueryOperation, retryCount: Int = 0) {
            queryOperation.resultsLimit = CKQueryOperation.maximumResults

            queryOperation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let recipe = self.convertRecordToRecipe(record) {
                        fetchedRecipes.append(recipe)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = "Error fetching record \(recordID.recordName): \(error.localizedDescription)"
                    }
                    print("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
                }
            }

            queryOperation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        // More records available, continue fetching
                        let nextOperation = CKQueryOperation(cursor: cursor)
                        fetch(with: nextOperation, retryCount: retryCount)
                    } else {
                        // No more records – update UI and cache
                        DispatchQueue.main.async {
                            self.recipes = fetchedRecipes.sorted(by: { $0.name < $1.name })
                            self.syncFavorites()
                            self.saveRecipesToLocalCache(fetchedRecipes)
                            self.lastUpdated = Date()
                            self.isLoading = false
                            completion()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        let errorType = self.errorType(for: error)
                        self.errorMessage = errorType.rawValue
                        self.accessibilityAnnouncement = errorType.rawValue
                        self.isLoading = false
                        print("Error fetching recipes (attempt \(retryCount + 1)): \(error.localizedDescription)")
                    }
                    // Retry logic for transient errors
                    if let ckError = error as? CKError, ckError.isRetryable, retryCount < 3 {
                        print("Retrying fetch (attempt \(retryCount + 2))...")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                            let retryOperation = CKQueryOperation(query: query)
                            fetch(with: retryOperation, retryCount: retryCount + 1)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion()
                        }
                    }
                }
            }

            publicDatabase.add(queryOperation)
        }

        // Start with the initial query operation
        let initialOperation = CKQueryOperation(query: query)
        fetch(with: initialOperation)
    }

    // Asynchronous wrapper using async/await
    func loadDataAsync() async {
        await withCheckedContinuation { continuation in
            loadData {
                continuation.resume()
            }
        }
    }

    // MARK: - Local File Cache Methods

    private func localCacheFileName() -> String {
        return "recipes.json"
    }

    private func loadRecipesFromLocalCache() -> [Recipe]? {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        print("Attempting to load local cache from: \(fileURL.path)")
        guard let data = try? Data(contentsOf: fileURL) else {
            print("No data found at \(fileURL.path)")
            return nil
        }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }

    private func saveRecipesToLocalCache(_ recipes: [Recipe]) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        if let data = try? JSONEncoder().encode(recipes) {
            do {
                try data.write(to: fileURL)
                print("Saved \(recipes.count) recipes to local cache at \(fileURL.path)")
            } catch {
                print("Error saving recipes to local cache: \(error.localizedDescription)")
            }
        }
    }

    private func getCacheDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Clear Cache

    func clearCache(completion: @escaping (Bool) -> Void) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        do {
            try FileManager.default.removeItem(at: fileURL)
            DispatchQueue.main.async {
                self.recipes = []
                self.cacheClearedMessage = "Cache cleared successfully."
                self.accessibilityAnnouncement = "Cache cleared successfully."
            }
            completion(true)
        } catch {
            DispatchQueue.main.async {
                self.cacheClearedMessage = "Failed to clear cache."
                self.accessibilityAnnouncement = "Failed to clear cache."
            }
            completion(false)
        }
    }

    // MARK: - Record Conversion

    private func convertRecordToRecipe(_ record: CKRecord) -> Recipe? {
        guard let name = record["name"] as? String,
              let image = record["image"] as? String,
              let ingredients = record["ingredients"] as? [String],
              let outputInt64 = record["output"] as? Int64,
              let category = record["category"] as? String else {
            print("Missing field in record \(record.recordID.recordName)")
            return nil
        }
        let id = Int(record.recordID.recordName) ?? 0
        let output = Int(outputInt64)
        let imageremark = record["imageremark"] as? String
        let remarks = record["remarks"] as? String
        let alt0 = record["alternateIngredients"]   as? [String]
        let alt1 = record["alternateIngredients1"]  as? [String]
        let alt2 = record["alternateIngredients2"]  as? [String]
        let alt3 = record["alternateIngredients3"]  as? [String]
        let altOutput0 = (record["alternateOutput"]   as? Int64).map(Int.init)
        let altOutput1 = (record["alternateOutput1"]  as? Int64).map(Int.init)
        let altOutput2 = (record["alternateOutput2"]  as? Int64).map(Int.init)
        let altOutput3 = (record["alternateOutput3"]  as? Int64).map(Int.init)

        return Recipe(
            id: id,
            name: name,
            image: image,
            ingredients: ingredients,
            alternateIngredients:   alt0,
            alternateIngredients1:  alt1,
            alternateIngredients2:  alt2,
            alternateIngredients3:  alt3,
            output:                output,
            alternateOutput:       altOutput0,
            alternateOutput1:      altOutput1,
            alternateOutput2:      altOutput2,
            alternateOutput3:      altOutput3,
            category:              category,
            imageremark:           imageremark,
            remarks:               remarks
        )
    }

    // MARK: - Error Handling

    private func errorType(for error: Error) -> ErrorType {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
                return .network
            case .notAuthenticated, .permissionFailure:
                return .permissions
            case .unknownItem, .invalidArguments:
                return .dataCorruption
            default:
                return .unknown
            }
        }
        return .unknown
    }

    // MARK: - Helper Properties

    var categories: [String] {
        let uniqueCategories = Set(recipes.map { $0.category })
        return Array(uniqueCategories).sorted()
    }

    var filteredRecipes: [Recipe] {
        if let category = selectedCategory {
            return recipes.filter { $0.category == category }
        } else {
            return recipes
        }
    }
}

extension CKError {
    var isRetryable: Bool {
        switch self.code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
            return true
        default:
            return false
        }
    }
}

