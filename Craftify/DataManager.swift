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
import Network

class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var favorites: [Recipe] = []
    @Published var recentSearchNames: [String] = []
    @Published var selectedCategory: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var cacheClearedMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var isManualSyncing: Bool = false
    @Published var accessibilityAnnouncement: String? = nil
    @Published var searchText: String = ""
    @Published var lastReportStatusFetchTime: Date? = nil
    @Published var lastRecipeFetch: Date? = nil
    @Published var isConnected: Bool = true

    private let iCloudFavoritesKey = "favoriteRecipes"
    private let iCloudRecentSearchesKey = "recentSearches"
    private var cancellables = Set<AnyCancellable>()
    private let reportStatusFetchInterval: TimeInterval = 30
    private let recipeFetchInterval: TimeInterval = 60
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    private let container = CKContainer(identifier: "iCloud.craftifydb")
    private lazy var publicDatabase = container.publicCloudDatabase
    private lazy var privateDatabase = container.privateCloudDatabase

    enum ErrorType: String {
        case network            = "Network issue, please check your connection and try again."
        case permissions        = "Permission denied, please enable iCloud access."
        case dataCorruption     = "Data error, please try refreshing."
        case userIdentification = "Unable to identify user. Please ensure iCloud is enabled."
        case missingFields      = "Report data is incomplete or corrupted."
        case unknown            = "An unexpected error occurred."
    }

    init() {
        NSUbiquitousKeyValueStore.default.synchronize()

        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isConnected = (path.status == .satisfied)
                if !self.isConnected {
                    self.errorMessage = "No internet connection. Please connect to sync data."
                    self.accessibilityAnnouncement = self.errorMessage
                }
            }
        }
        networkMonitor.start(queue: networkQueue)

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
                guard let self = self else { return }
                if message != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.errorMessage = nil
                    }
                }
            }
            .store(in: &cancellables)

        $cacheClearedMessage
            .sink { [weak self] message in
                guard let self = self else { return }
                if let msg = message {
                    self.accessibilityAnnouncement = msg
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.cacheClearedMessage = nil
                        self.accessibilityAnnouncement = nil
                    }
                }
            }
            .store(in: &cancellables)

        if let localRecipes = loadRecipesFromLocalCache() {
            print("Loaded \(localRecipes.count) recipes from local cache.")
            self.recipes = localRecipes.sorted { $0.name < $1.name }
            self.syncFavorites()
            self.syncRecentSearches()
        } else {
            print("No local cache found; will fetch from CloudKit on first view load.")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        networkMonitor.cancel()
    }

    @objc private func appWillEnterForeground() {
        NSUbiquitousKeyValueStore.default.synchronize()
        self.syncFavorites()
        self.syncRecentSearches()
    }

    @objc private func icloudDidChange() {
        self.syncFavorites()
        self.syncRecentSearches()
    }

    var syncStatus: String {
        if !isConnected {
            return "No internet connection"
        } else if let updated = lastUpdated {
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            fmt.locale = .current
            fmt.timeZone = .current
            return "Last synced: \(fmt.string(from: updated))"
        } else if isLoading {
            return "Syncing recipes..."
        } else if let err = errorMessage {
            return "Sync failed: \(err)"
        } else {
            return "Not synced"
        }
    }

    // MARK: - Favorites

    func isFavorite(recipe: Recipe) -> Bool {
        favorites.contains { $0.id == recipe.id }
    }

    func toggleFavorite(recipe: Recipe) {
        if let idx = favorites.firstIndex(where: { $0.id == recipe.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(recipe)
        }
        saveFavorites()
    }

    func saveFavorites() {
        let ids = favorites.map { $0.id }
        NSUbiquitousKeyValueStore.default.set(ids, forKey: iCloudFavoritesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func syncFavorites() {
        if let saved = NSUbiquitousKeyValueStore.default.array(forKey: iCloudFavoritesKey) as? [Int] {
            favorites = recipes.filter { saved.contains($0.id) }
        }
    }

    func clearFavorites() {
        favorites.removeAll()
        NSUbiquitousKeyValueStore.default.set([], forKey: iCloudFavoritesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Recent Searches

    func saveRecentSearch(_ recipe: Recipe) {
        recentSearchNames.removeAll { $0 == recipe.name }
        recentSearchNames.insert(recipe.name, at: 0)
        recentSearchNames = Array(recentSearchNames.prefix(10))
        NSUbiquitousKeyValueStore.default.set(recentSearchNames, forKey: iCloudRecentSearchesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func syncRecentSearches() {
        if let saved = NSUbiquitousKeyValueStore.default.array(forKey: iCloudRecentSearchesKey) as? [String] {
            recentSearchNames = Array(saved.prefix(10))
                .filter { name in recipes.contains { $0.name == name } }
        }
    }

    func clearRecentSearches() {
        recentSearchNames.removeAll()
        NSUbiquitousKeyValueStore.default.set([], forKey: iCloudRecentSearchesKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Recipe Fetching

    func fetchRecipes(isManual: Bool = false, completion: @escaping () -> Void = {}) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.errorMessage = "No internet connection. Please connect to sync recipes."
                self.accessibilityAnnouncement = self.errorMessage
                completion()
            }
            return
        }
        if let last = lastRecipeFetch,
           Date().timeIntervalSince(last) < recipeFetchInterval {
            print("Skipping recipe fetch; last fetch was less than \(recipeFetchInterval) seconds ago.")
            completion()
            return
        }
        loadData(isManual: isManual, completion: completion)
    }

    private func loadData(isManual: Bool, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            if isManual { self.isManualSyncing = true }
            self.errorMessage = nil
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        var fetchedRecipes: [Recipe] = []

        func performFetch(_ operation: CKQueryOperation, retryCount: Int = 0) {
            operation.resultsLimit = CKQueryOperation.maximumResults

            operation.recordMatchedBlock = { [weak self] recordID, result in
                guard let self = self else { return }
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

            operation.queryResultBlock = { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        let nextOp = CKQueryOperation(cursor: cursor)
                        performFetch(nextOp, retryCount: retryCount)
                    } else {
                        DispatchQueue.main.async {
                            self.recipes = fetchedRecipes.sorted { $0.name < $1.name }
                            self.syncFavorites()
                            self.syncRecentSearches()
                            self.saveRecipesToLocalCache(fetchedRecipes)
                            self.lastUpdated = Date()
                            self.lastRecipeFetch = Date()
                            self.isLoading = false
                            self.isManualSyncing = false
                            completion()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = self.errorType(for: error).rawValue
                        self.accessibilityAnnouncement = self.errorMessage
                        self.isLoading = false
                        self.isManualSyncing = false
                    }
                    if let ckError = error as? CKError, ckError.isRetryable, retryCount < 3 {
                        DispatchQueue.main.async { self.isLoading = true }
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                            performFetch(CKQueryOperation(query: query), retryCount: retryCount + 1)
                        }
                    } else {
                        DispatchQueue.main.async { completion() }
                    }
                }
            }

            self.publicDatabase.add(operation)
        }

        performFetch(CKQueryOperation(query: query))
    }

    func loadDataAsync(isManual: Bool = false) async {
        await withCheckedContinuation { continuation in
            loadData(isManual: isManual) {
                continuation.resume()
            }
        }
    }

    func isRecipeFetchOnCooldown() -> Bool {
        if let last = lastRecipeFetch {
            return Date().timeIntervalSince(last) < recipeFetchInterval
        }
        return false
    }

    func isReportStatusFetchOnCooldown() -> Bool {
        if let last = lastReportStatusFetchTime {
            return Date().timeIntervalSince(last) < reportStatusFetchInterval
        }
        return false
    }

    // MARK: - Report Management

    func submitRecipeReport(
        reportType: String,
        recipeName: String,
        category: String,
        recipeID: Int?,
        description: String,
        completion: @escaping (Result<RecipeReport, Error>) -> Void
    ) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.errorMessage = "No internet connection. Please connect to submit a report."
                self.accessibilityAnnouncement = self.errorMessage
                completion(.failure(NSError(
                    domain: "DataManager",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
                )))
            }
            return
        }

        let record = CKRecord(recordType: "PublicRecipeReport")
        let localID = UUID().uuidString

        record["localID"]      = localID
        record["reportType"]   = reportType
        record["recipeName"]   = recipeName
        record["category"]     = category
        record["recipeID"]     = recipeID
        record["description"]  = description
        record["timestamp"]    = Date()
        record["status"]       = "Pending"

        publicDatabase.save(record) { [weak self] saved, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    let type = self.errorType(for: error)
                    self.errorMessage = "Failed to submit report: \(type.rawValue)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(.failure(error))
                } else if let saved = saved {
                    let report = RecipeReport(
                        id: localID,
                        recordID: saved.recordID.recordName,
                        localID: localID,
                        reportType: reportType,
                        recipeName: recipeName,
                        category: category,
                        recipeID: recipeID,
                        description: description,
                        timestamp: Date(),
                        status: "Pending"
                    )
                    self.accessibilityAnnouncement = "Report submitted successfully"
                    self.lastReportStatusFetchTime = nil
                    completion(.success(report))
                }
            }
        }
    }

    func fetchRecipeReports(completion: @escaping (Result<[RecipeReport], Error>) -> Void) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.errorMessage = "No internet connection. Please connect to fetch reports."
                self.accessibilityAnnouncement = self.errorMessage
                completion(.failure(NSError(
                    domain: "DataManager",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
                )))
            }
            return
        }

        if let last = lastReportStatusFetchTime,
           Date().timeIntervalSince(last) < reportStatusFetchInterval {
            print("Skipping report fetch; last fetch was less than \(reportStatusFetchInterval) seconds ago.")
            completion(.success([]))
            return
        }

        container.fetchUserRecordID { [weak self] userRecordID, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch user ID: \(error.localizedDescription)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(.failure(error))
                }
                return
            }
            guard let userRecordID = userRecordID else {
                DispatchQueue.main.async {
                    self.errorMessage = ErrorType.userIdentification.rawValue
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(.failure(NSError(
                        domain: "DataManager",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "User record ID not found"]
                    )))
                }
                return
            }

            let predicate = NSPredicate(format: "creatorUserRecordID == %@", userRecordID)
            let query = CKQuery(recordType: "PublicRecipeReport", predicate: predicate)
            var fetchedReports: [RecipeReport] = []

            func performFetch(_ operation: CKQueryOperation) {
                operation.resultsLimit = CKQueryOperation.maximumResults

                operation.recordMatchedBlock = { [weak self] _, result in
                    guard let self = self else { return }
                    if case .success(let record) = result,
                       let localID    = record["localID"]    as? String,
                       let type       = record["reportType"] as? String,
                       let name       = record["recipeName"] as? String,
                       let cat        = record["category"]   as? String,
                       let desc       = record["description"]as? String,
                       let ts         = record["timestamp"]  as? Date,
                       let status     = record["status"]     as? String {
                        let report = RecipeReport(
                            id: localID,
                            recordID: record.recordID.recordName,
                            localID: localID,
                            reportType: type,
                            recipeName: name,
                            category: cat,
                            recipeID: record["recipeID"] as? Int,
                            description: desc,
                            timestamp: ts,
                            status: status
                        )
                        fetchedReports.append(report)
                    } else if case .failure(let error) = result {
                        DispatchQueue.main.async {
                            self.errorMessage = "Error fetching report: \(error.localizedDescription)"
                            self.accessibilityAnnouncement = self.errorMessage
                        }
                    }
                }

                operation.queryResultBlock = { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let cursor):
                            if let cursor = cursor {
                                performFetch(CKQueryOperation(cursor: cursor))
                            } else {
                                self.lastReportStatusFetchTime = Date()
                                completion(.success(fetchedReports))
                            }
                        case .failure(let error):
                            self.errorMessage = "Failed to fetch reports: \(error.localizedDescription)"
                            self.accessibilityAnnouncement = self.errorMessage
                            completion(.failure(error))
                        }
                    }
                }

                self.publicDatabase.add(operation)
            }

            performFetch(CKQueryOperation(query: query))
        }
    }

    func deleteRecipeReport(_ report: RecipeReport, completion: @escaping (Bool) -> Void) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.errorMessage = "No internet connection. Please connect to delete the report."
                self.accessibilityAnnouncement = self.errorMessage
                completion(false)
            }
            return
        }
        guard let rid = report.recordID else {
            self.accessibilityAnnouncement = "Report deleted successfully"
            completion(true)
            return
        }
        publicDatabase.delete(withRecordID: CKRecord.ID(recordName: rid)) { [weak self] _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    self.accessibilityAnnouncement = "Report deleted successfully"
                    completion(true)
                } else if let error = error {
                    self.errorMessage = "Failed to delete report: \(error.localizedDescription)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(false)
                } else {
                    self.accessibilityAnnouncement = "Report deleted successfully"
                    completion(true)
                }
            }
        }
    }

    func deleteAllRecipeReports(reports: [RecipeReport], completion: @escaping (Bool) -> Void) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.errorMessage = "No internet connection. Please connect to delete reports."
                self.accessibilityAnnouncement = self.errorMessage
                completion(false)
            }
            return
        }
        let toDelete = reports.compactMap { $0.recordID }.map { CKRecord.ID(recordName: $0) }
        guard !toDelete.isEmpty else {
            self.accessibilityAnnouncement = "All reports deleted successfully"
            completion(true)
            return
        }
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: toDelete)
        operation.modifyRecordsResultBlock = { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.accessibilityAnnouncement = "All reports deleted successfully"
                    completion(true)
                case .failure(let error):
                    self.errorMessage = "Failed to delete all reports: \(error.localizedDescription)"
                    self.accessibilityAnnouncement = self.errorMessage
                    completion(false)
                }
            }
        }
        publicDatabase.add(operation)
    }

    // MARK: - Cache

    func clearCache(completion: @escaping (Bool) -> Void) {
        let url = getCacheDirectory().appendingPathComponent(localCacheFileName())
        do {
            try FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                self.recipes = []
                self.cacheClearedMessage = "Cache cleared successfully."
                self.accessibilityAnnouncement = "Cache cleared successfully."
                completion(true)
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
        clearCache { [weak self] cacheSuccess in
            guard let self = self else { return }
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

    // MARK: - Local Cache Helpers

    private func localCacheFileName() -> String {
        "recipes.json"
    }

    private func loadRecipesFromLocalCache() -> [Recipe]? {
        let url = getCacheDirectory().appendingPathComponent(localCacheFileName())
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }

    private func saveRecipesToLocalCache(_ recipes: [Recipe]) {
        let url = getCacheDirectory().appendingPathComponent(localCacheFileName())
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        try? data.write(to: url)
    }

    private func getCacheDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func convertRecordToRecipe(_ record: CKRecord) -> Recipe? {
        guard
            let name        = record["name"] as? String,
            let image       = record["image"] as? String,
            let ingredients = record["ingredients"] as? [String],
            let outputInt   = record["output"] as? Int64,
            let category    = record["category"] as? String
        else {
            return nil
        }

        return Recipe(
            id: Int(record.recordID.recordName) ?? 0,
            name: name,
            image: image,
            ingredients: ingredients,
            alternateIngredients:  record["alternateIngredients"]  as? [String],
            alternateIngredients1: record["alternateIngredients1"] as? [String],
            alternateIngredients2: record["alternateIngredients2"] as? [String],
            alternateIngredients3: record["alternateIngredients3"] as? [String],
            output: Int(outputInt),
            alternateOutput:  (record["alternateOutput"]  as? Int64).map(Int.init),
            alternateOutput1: (record["alternateOutput1"] as? Int64).map(Int.init),
            alternateOutput2: (record["alternateOutput2"] as? Int64).map(Int.init),
            alternateOutput3: (record["alternateOutput3"] as? Int64).map(Int.init),
            category: category,
            imageremark: record["imageremark"] as? String,
            remarks:     record["remarks"]    as? String
        )
    }

    private func errorType(for err: Error) -> ErrorType {
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
        Set(recipes.map { $0.category }).sorted()
    }

    var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            (selectedCategory == nil || recipe.category == selectedCategory) &&
            (searchText.isEmpty || recipe.name.contains(searchText.lowercased()))
        }
    }
}

extension CKError {
    var isRetryable: Bool {
        switch code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
            return true
        default:
            return false
        }
    }
}
