//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import Combine
import CloudKit
import UIKit

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var favorites: [Recipe] = []
    @Published var recentSearchNames: [String] = []
    @Published var submittedReports: [RecipeReport] = []
    @Published var selectedCategory: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var cacheClearedMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var isManualSyncing: Bool = false
    @Published var accessibilityAnnouncement: String? = nil
    @Published var searchText: String = ""

    private let iCloudFavoritesKey = "favoriteRecipes"
    private let iCloudRecentSearchesKey = "recentSearches"
    private let submittedReportsKey = "submittedReports"
    private var cancellables = Set<AnyCancellable>()
    private var lastReportStatusFetch: Date?
    private let reportStatusFetchInterval: TimeInterval = 30 // Fetch statuses no more than once every 30 seconds
    private var lastRecipeFetch: Date? // New property for recipe fetch throttling
    private let recipeFetchInterval: TimeInterval = 30 // New constant for recipe fetch cooldown

    enum ErrorType: String {
        case network = "Network issue, please check your connection and try again."
        case permissions = "Permission denied, please enable iCloud access."
        case dataCorruption = "Data error, please try refreshing."
        case unknown = "An unexpected error occurred."
    }

    init() {
        NSUbiquitousKeyValueStore.default.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(icloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

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

        if let localRecipes = loadRecipesFromLocalCache() {
            print("Loaded \(localRecipes.count) recipes from local cache.")
            self.recipes = localRecipes.sorted(by: { $0.name < $1.name })
            self.syncFavorites()
            self.syncRecentSearches()
            self.loadSubmittedReports()
        } else {
            print("No local cache found; will fetch from CloudKit on first view load.")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillEnterForeground() {
        NSUbiquitousKeyValueStore.default.synchronize()
        syncFavorites()
        syncRecentSearches()
    }

    var syncStatus: String {
        if let lastUpdated = lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            return "Last synced: \(formatter.string(from: lastUpdated))"
        } else if isLoading {
            return "Syncing recipes..."
        } else if let errorMessage = errorMessage {
            return "Sync failed: \(errorMessage)"
        } else {
            return "Not synced"
        }
    }

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
        NSUbiquitousKeyValueStore.default.set(favoriteIDs, forKey: iCloudFavoritesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func syncFavorites() {
        if let savedIDs = NSUbiquitousKeyValueStore.default.array(forKey: iCloudFavoritesKey) as? [Int] {
            favorites = recipes.filter { savedIDs.contains($0.id) }
        }
    }

    func clearFavorites() {
        favorites = []
        NSUbiquitousKeyValueStore.default.set(favorites.map { $0.id }, forKey: iCloudFavoritesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        print("Cleared favorite recipes: \(favorites)")
    }

    func saveRecentSearch(_ recipe: Recipe) {
        recentSearchNames.removeAll { $0 == recipe.name }
        recentSearchNames.insert(recipe.name, at: 0)
        recentSearchNames = Array(recentSearchNames.prefix(10))
        print("Updated recent search names: \(recentSearchNames)")
        
        NSUbiquitousKeyValueStore.default.set(recentSearchNames, forKey: iCloudRecentSearchesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func clearRecentSearches() {
        recentSearchNames = []
        NSUbiquitousKeyValueStore.default.set(recentSearchNames, forKey: iCloudRecentSearchesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        print("Cleared recent search names: \(recentSearchNames)")
    }

    func syncRecentSearches() {
        if let savedNames = NSUbiquitousKeyValueStore.default.array(forKey: iCloudRecentSearchesKey) as? [String] {
            recentSearchNames = Array(savedNames.prefix(10)).filter { name in recipes.contains { $0.name == name } }
        }
    }

    @objc private func icloudDidChange() {
        syncFavorites()
        syncRecentSearches()
    }

    func fetchRecipes(isManual: Bool = false, completion: @escaping () -> Void = {}) {
        // Throttle recipe fetches to avoid overloading CloudKit
        if let lastFetch = lastRecipeFetch,
           Date().timeIntervalSince(lastFetch) < recipeFetchInterval {
            print("Skipping recipe fetch; last fetch was less than \(recipeFetchInterval) seconds ago.")
            completion()
            return
        }

        loadData(isManual: isManual, completion: completion)
    }

    func loadData(isManual: Bool, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            if isManual {
                self.isManualSyncing = true
            }
            self.errorMessage = nil
        }

        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)

        var fetchedRecipes: [Recipe] = []

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
                }
            }

            queryOperation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        let nextOperation = CKQueryOperation(cursor: cursor)
                        fetch(with: nextOperation, retryCount: retryCount)
                    } else {
                        DispatchQueue.main.async {
                            self.recipes = fetchedRecipes.sorted(by: { $0.name < $1.name })
                            self.syncFavorites()
                            self.syncRecentSearches()
                            self.saveRecipesToLocalCache(fetchedRecipes)
                            self.lastUpdated = Date()
                            self.lastRecipeFetch = Date() // Update the last fetch time
                            self.isLoading = false
                            self.isManualSyncing = false
                            completion()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        let errorType = self.errorType(for: error)
                        self.errorMessage = errorType.rawValue
                        self.accessibilityAnnouncement = errorType.rawValue
                        self.isLoading = false
                        self.isManualSyncing = false
                    }

                    if let ckError = error as? CKError, ckError.isRetryable, retryCount < 3 {
                        DispatchQueue.main.async {
                            self.isLoading = true
                        }
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

        let initialOperation = CKQueryOperation(query: query)
        fetch(with: initialOperation)
    }

    func loadDataAsync(isManual: Bool = false) async {
        await withCheckedContinuation { continuation in
            loadData(isManual: isManual) {
                continuation.resume()
            }
        }
    }

    // MARK: - Throttling Helpers

    func isRecipeFetchOnCooldown() -> Bool {
        if let lastFetch = lastRecipeFetch {
            return Date().timeIntervalSince(lastFetch) < recipeFetchInterval
        }
        return false
    }

    func isReportStatusFetchOnCooldown() -> Bool {
        if let lastFetch = lastReportStatusFetch {
            return Date().timeIntervalSince(lastFetch) < reportStatusFetchInterval
        }
        return false
    }

    // MARK: - Recipe Report Management

    func loadSubmittedReports() {
        if let data = UserDefaults.standard.data(forKey: submittedReportsKey),
           let reports = try? JSONDecoder().decode([RecipeReport].self, from: data) {
            self.submittedReports = reports
        } else {
            self.submittedReports = []
        }
    }

    func saveSubmittedReports() {
        if let data = try? JSONEncoder().encode(submittedReports) {
            UserDefaults.standard.set(data, forKey: submittedReportsKey)
        }
    }

    func submitRecipeReport(
        reportType: String,
        recipeName: String,
        category: String,
        recipeID: Int?,
        description: String,
        completion: @escaping (Result<RecipeReport, Error>) -> Void
    ) {
        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase
        let record = CKRecord(recordType: "RecipeReport")
        let localID = UUID().uuidString

        record["localID"] = localID
        record["reportType"] = reportType
        record["recipeName"] = recipeName
        record["category"] = category
        record["recipeID"] = recipeID
        record["description"] = description
        record["timestamp"] = Date()
        record["status"] = "Pending"

        publicDatabase.save(record) { record, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorType = self.errorType(for: error)
                    self.errorMessage = "Failed to submit report: \(errorType.rawValue)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(.failure(error))
                } else if let savedRecord = record {
                    let report = RecipeReport(
                        id: localID,
                        recordID: savedRecord.recordID.recordName,
                        localID: localID,
                        reportType: reportType,
                        recipeName: recipeName,
                        category: category,
                        recipeID: recipeID,
                        description: description,
                        timestamp: Date(),
                        status: "Pending"
                    )
                    self.submittedReports.append(report)
                    self.saveSubmittedReports()
                    self.accessibilityAnnouncement = "Report submitted successfully"
                    completion(.success(report))
                }
            }
        }
    }

    func fetchRecipeReportStatuses(completion: @escaping () -> Void) {
        // Throttle status fetches to avoid overloading CloudKit
        if let lastFetch = lastReportStatusFetch,
           Date().timeIntervalSince(lastFetch) < reportStatusFetchInterval {
            print("Skipping report status fetch; last fetch was less than \(reportStatusFetchInterval) seconds ago.")
            completion()
            return
        }

        guard !submittedReports.isEmpty else {
            completion()
            return
        }

        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase
        let localIDs = submittedReports.map { $0.localID }
        let predicate = NSPredicate(format: "localID IN %@", localIDs)
        let query = CKQuery(recordType: "RecipeReport", predicate: predicate)

        var updatedReports = submittedReports
        var foundLocalIDs: Set<String> = []

        func fetch(with queryOperation: CKQueryOperation) {
            queryOperation.resultsLimit = CKQueryOperation.maximumResults

            queryOperation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let localID = record["localID"] as? String,
                       let status = record["status"] as? String,
                       let index = updatedReports.firstIndex(where: { $0.localID == localID }) {
                        updatedReports[index].status = status
                        foundLocalIDs.insert(localID)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        let errorType = self.errorType(for: error)
                        self.errorMessage = "Error fetching report status for \(recordID.recordName): \(errorType.rawValue)"
                        self.accessibilityAnnouncement = self.errorMessage
                    }
                }
            }

            queryOperation.queryResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let cursor):
                        if let cursor = cursor {
                            let nextOperation = CKQueryOperation(cursor: cursor)
                            fetch(with: nextOperation)
                        } else {
                            // Remove reports that no longer exist in CloudKit
                            let missingLocalIDs = Set(localIDs).subtracting(foundLocalIDs)
                            updatedReports.removeAll { report in
                                missingLocalIDs.contains(report.localID)
                            }
                            self.submittedReports = updatedReports
                            self.saveSubmittedReports()
                            self.lastReportStatusFetch = Date()
                            completion()
                        }
                    case .failure(let error):
                        let errorType = self.errorType(for: error)
                        self.errorMessage = "Failed to fetch report statuses: \(errorType.rawValue)"
                        self.accessibilityAnnouncement = self.errorMessage
                        completion()
                    }
                }
            }

            publicDatabase.add(queryOperation)
        }

        let initialOperation = CKQueryOperation(query: query)
        fetch(with: initialOperation)
    }

    func deleteRecipeReport(_ report: RecipeReport, completion: @escaping (Bool) -> Void) {
        guard let recordIDString = report.recordID else {
            // If there's no recordID, remove locally and consider it a success
            self.submittedReports.removeAll { $0.id == report.id }
            self.saveSubmittedReports()
            self.accessibilityAnnouncement = "Report deleted successfully"
            completion(true)
            return
        }

        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: recordIDString)

        publicDatabase.delete(withRecordID: recordID) { _, error in
            DispatchQueue.main.async {
                if let error = error as? CKError, error.code == .unknownItem {
                    // If the record doesn't exist in CloudKit, remove it locally and consider it a success
                    self.submittedReports.removeAll { $0.id == report.id }
                    self.saveSubmittedReports()
                    self.accessibilityAnnouncement = "Report deleted successfully"
                    completion(true)
                } else if let error = error {
                    let errorType = self.errorType(for: error)
                    self.errorMessage = "Failed to delete report: \(errorType.rawValue)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(false)
                } else {
                    self.submittedReports.removeAll { $0.id == report.id }
                    self.saveSubmittedReports()
                    self.accessibilityAnnouncement = "Report deleted successfully"
                    completion(true)
                }
            }
        }
    }

    func deleteAllRecipeReports(completion: @escaping (Bool) -> Void) {
        let reportsWithRecordID = submittedReports.filter { $0.recordID != nil }
        guard !reportsWithRecordID.isEmpty else {
            self.submittedReports = []
            self.saveSubmittedReports()
            self.accessibilityAnnouncement = "All reports deleted successfully"
            completion(true)
            return
        }

        let container = CKContainer(identifier: "iCloud.craftifydb")
        let publicDatabase = container.publicCloudDatabase
        let recordIDs = reportsWithRecordID.compactMap { $0.recordID }.map { CKRecord.ID(recordName: $0) }
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)

        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.submittedReports = []
                    self.saveSubmittedReports()
                    self.accessibilityAnnouncement = "All reports deleted successfully"
                    completion(true)
                case .failure(let error):
                    let errorType = self.errorType(for: error)
                    self.errorMessage = "Failed to delete all reports: \(errorType.rawValue)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(false)
                }
            }
        }

        publicDatabase.add(operation)
    }

    // MARK: - Data Management

    func clearCache(completion: @escaping (Bool) -> Void) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        do {
            try FileManager.default.removeItem(at: fileURL)
            DispatchQueue.main.async {
                self.recipes = []
                self.deleteAllRecipeReports { success in
                    if success {
                        self.cacheClearedMessage = "Cache and reports cleared successfully."
                        self.accessibilityAnnouncement = "Cache and reports cleared successfully."
                        completion(true)
                    } else {
                        self.cacheClearedMessage = "Cache cleared, but failed to clear reports."
                        self.accessibilityAnnouncement = "Cache cleared, but failed to clear reports."
                        completion(false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.cacheClearedMessage = "Failed to clear cache."
                self.accessibilityAnnouncement = "Failed to clear cache."
                completion(false)
            }
        }
    }

    func clearAllData(completion: @escaping (Bool) -> Void) {
        // Step 1: Clear recipe cache and CloudKit reports
        clearCache { cacheSuccess in
            // Step 2: Clear favorites and recent searches
            self.clearFavorites()
            self.clearRecentSearches()
            
            DispatchQueue.main.async {
                if cacheSuccess {
                    self.cacheClearedMessage = "All data cleared successfully."
                    self.accessibilityAnnouncement = "All data cleared successfully."
                    completion(true)
                } else {
                    self.cacheClearedMessage = "Failed to clear all data."
                    self.accessibilityAnnouncement = "Failed to clear all data."
                    completion(false)
                }
            }
        }
    }

    private func localCacheFileName() -> String {
        return "recipes.json"
    }

    private func loadRecipesFromLocalCache() -> [Recipe]? {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }

    private func saveRecipesToLocalCache(_ recipes: [Recipe]) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        if let data = try? JSONEncoder().encode(recipes) {
            do {
                try data.write(to: fileURL)
            } catch {
                print("Error saving recipes to local cache: \(error.localizedDescription)")
            }
        }
    }

    private func getCacheDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func convertRecordToRecipe(_ record: CKRecord) -> Recipe? {
        guard let name = record["name"] as? String,
              let image = record["image"] as? String,
              let ingredients = record["ingredients"] as? [String],
              let outputInt64 = record["output"] as? Int64,
              let category = record["category"] as? String else {
            return nil
        }

        let id = Int(record.recordID.recordName) ?? 0
        let output = Int(outputInt64)
        let imageremark = record["imageremark"] as? String
        let remarks = record["remarks"] as? String
        let alt0 = record["alternateIngredients"] as? [String]
        let alt1 = record["alternateIngredients1"] as? [String]
        let alt2 = record["alternateIngredients2"] as? [String]
        let alt3 = record["alternateIngredients3"] as? [String]
        let altOutput0 = (record["alternateOutput"] as? Int64).map(Int.init)
        let altOutput1 = (record["alternateOutput1"] as? Int64).map(Int.init)
        let altOutput2 = (record["alternateOutput2"] as? Int64).map(Int.init)
        let altOutput3 = (record["alternateOutput3"] as? Int64).map(Int.init)

        return Recipe(
            id: id,
            name: name,
            image: image,
            ingredients: ingredients,
            alternateIngredients: alt0,
            alternateIngredients1: alt1,
            alternateIngredients2: alt2,
            alternateIngredients3: alt3,
            output: output,
            alternateOutput: altOutput0,
            alternateOutput1: altOutput1,
            alternateOutput2: altOutput2,
            alternateOutput3: altOutput3,
            category: category,
            imageremark: imageremark,
            remarks: remarks
        )
    }

    private func errorType(for err: Swift.Error) -> ErrorType {
        if let ckError = err as? CKError {
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

    var categories: [String] {
        let uniqueCategories = Set(recipes.map { $0.category })
        return Array(uniqueCategories).sorted()
    }

    var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesCategory = selectedCategory == nil || recipe.category == selectedCategory
            let matchesSearch = searchText.isEmpty || recipe.name.lowercased().contains(searchText.lowercased())
            return matchesCategory && matchesSearch
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
