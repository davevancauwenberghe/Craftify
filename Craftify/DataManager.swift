//
//  DataManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import Combine
@preconcurrency import CloudKit
import UIKit
import Network

@MainActor
final class DataManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published private(set) var chests: [RecipeChest] = []
    @Published var recentSearchNames: [String] = []
    @Published var selectedCategory: String? = nil
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var cacheClearedMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var isManualSyncing: Bool = false
    @Published var accessibilityAnnouncement: String? = nil
    @Published var searchText: String = ""
    @Published var lastReportStatusFetchTime: Date?
    @Published var lastRecipeFetch: Date?
    @Published var isConnected: Bool = true
    @Published var consoleCommands: [ConsoleCommand] = []

    private let iCloudFavoritesKey = "favoriteRecipes"
    private let iCloudChestsKey = "recipeChests.v1"
    private let iCloudRecentSearchesKey = "recentSearches"
    private var cancellables = Set<AnyCancellable>()
    private let reportStatusFetchInterval: TimeInterval = 30
    private let recipeFetchInterval: TimeInterval = 30
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    enum ErrorType: String {
        case network = "Network issue, please try again later."
        case permissions = "Permission denied, please enable iCloud access."
        case dataCorruption = "Data error, please try refreshing."
        case userIdentification = "Unable to identify user. Please ensure iCloud is enabled."
        case missingFields = "Report data is incomplete or corrupted."
        case unknown = "An unexpected error occurred. Please try again later."
    }

    init() {
        NSUbiquitousKeyValueStore.default.synchronize()

        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                if !(self?.isConnected ?? true) {
                    self?.errorMessage = "No internet connection. Try again later."
                    self?.accessibilityAnnouncement = self?.errorMessage
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
            self.syncRecentSearches()
        } else {
            print("No local cache found; will fetch from CloudKit on first view load.")
        }

        fetchConsoleCommands()
        syncChests()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        networkMonitor.cancel()
    }

    @objc nonisolated private func appWillEnterForeground() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            NSUbiquitousKeyValueStore.default.synchronize()
            syncChests()
            syncRecentSearches()
        }
    }

    var syncStatus: String {
        if !isConnected {
            return "No internet connection"
        } else if let lastUpdated = lastUpdated {
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

    func clearChestsAndLegacyFavorites() {
        chests = []
        let store = NSUbiquitousKeyValueStore.default
        store.removeObject(forKey: iCloudFavoritesKey)
        store.removeObject(forKey: iCloudChestsKey)
        store.synchronize()
        print("Cleared chests and legacy favorites")
    }

    func createChest(name: String, size: RecipeChest.Size, adding recipe: Recipe? = nil) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipeIDs = recipe.map { [$0.id] } ?? []
        chests.append(RecipeChest(name: cleanedName.isEmpty ? "New Chest" : cleanedName, size: size, recipeIDs: recipeIDs))
        saveChests()
    }

    @discardableResult
    func updateChest(
        _ chest: RecipeChest,
        name: String,
        size: RecipeChest.Size,
        removingOverflow: Bool = false
    ) -> Bool {
        guard let index = chests.firstIndex(where: { $0.id == chest.id }) else { return false }
        let overflowCount = max(0, chests[index].recipeIDs.count - size.rawValue)
        guard overflowCount == 0 || removingOverflow else { return false }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        chests[index].name = cleanedName.isEmpty ? chest.name : cleanedName
        chests[index].size = size
        if overflowCount > 0 {
            chests[index].recipeIDs.removeLast(overflowCount)
        }
        saveChests()
        return true
    }

    @discardableResult
    func add(_ recipe: Recipe, to chest: RecipeChest) -> Bool {
        guard let index = chests.firstIndex(where: { $0.id == chest.id }),
              !chests[index].recipeIDs.contains(recipe.id),
              chests[index].recipeIDs.count < chests[index].size.rawValue else { return false }
        chests[index].recipeIDs.append(recipe.id)
        saveChests()
        return true
    }

    func removeRecipes(withIDs recipeIDs: Set<Int>, from chestID: UUID) {
        guard let index = chests.firstIndex(where: { $0.id == chestID }) else { return }
        chests[index].recipeIDs.removeAll { recipeIDs.contains($0) }
        saveChests()
    }

    func deleteChests(at offsets: IndexSet) {
        chests.remove(atOffsets: offsets)
        saveChests()
    }

    func moveChests(from source: IndexSet, to destination: Int) {
        chests.move(fromOffsets: source, toOffset: destination)
        saveChests()
    }

    func recipes(in chest: RecipeChest) -> [Recipe] {
        chest.recipeIDs.compactMap { id in recipes.first { $0.id == id } }
    }

    func syncChests() {
        let store = NSUbiquitousKeyValueStore.default
        if let data = store.data(forKey: iCloudChestsKey),
           let decoded = try? JSONDecoder().decode([RecipeChest].self, from: data) {
            chests = decoded
        }
    }

    private func saveChests() {
        guard let data = try? JSONEncoder().encode(chests) else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudChestsKey)
        NSUbiquitousKeyValueStore.default.synchronize()
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
            recentSearchNames = Array(savedNames.prefix(10)).filter { name in
                recipes.contains { $0.name == name }
            }
        }
    }

    @objc nonisolated private func icloudDidChange() {
        // iCloud posts this notification on the queue where the change arrives,
        // which is not guaranteed to be the main queue. Hop to the main actor
        // before reading iCloud values or updating observable state.
        Task { @MainActor [weak self] in
            self?.syncChests()
            self?.syncRecentSearches()
        }
    }

    func fetchRecipes(isManual: Bool = false, completion: @escaping () -> Void = {}) {
        if !isConnected {
            errorMessage = "No internet connection. Try again later."
            accessibilityAnnouncement = errorMessage
            completion()
            return
        }

        if let lastFetch = lastRecipeFetch,
           Date().timeIntervalSince(lastFetch) < recipeFetchInterval {
            print("Skipping recipe fetch; last fetch was less than \(recipeFetchInterval) seconds ago.")
            completion()
            return
        }

        loadData(isManual: isManual, completion: completion)
    }

    func loadData(isManual: Bool = false, completion: @escaping () -> Void) {
        Task {
            await loadData(isManual: isManual)
            completion()
        }
    }

    func loadDataAsync(isManual: Bool = false) async {
        await withCheckedContinuation { continuation in
            loadData(isManual: isManual) { continuation.resume() }
        }
    }

    private func loadData(isManual: Bool) async {
        isLoading = true
        if isManual { isManualSyncing = true }
        errorMessage = nil

        let database = CKContainer(identifier: "iCloud.craftifydb").publicCloudDatabase
        let query = CKQuery(recordType: "Recipe", predicate: NSPredicate(value: true))

        for retryCount in 0...3 {
            do {
                let records = try await fetchAllRecords(matching: query, from: database)
                let fetchedRecipes = records.compactMap(convertRecordToRecipe)
                recipes = fetchedRecipes.sorted { $0.name < $1.name }
                syncRecentSearches()
                saveRecipesToLocalCache(fetchedRecipes)
                lastUpdated = Date()
                lastRecipeFetch = Date()
                isLoading = false
                isManualSyncing = false
                return
            } catch {
                if let ckError = error as? CKError, ckError.isRetryable, retryCount < 3 {
                    try? await Task.sleep(for: .seconds(3))
                    continue
                }
                let type = errorType(for: error)
                errorMessage = type.rawValue
                accessibilityAnnouncement = type.rawValue
                isLoading = false
                isManualSyncing = false
                return
            }
        }
    }

    func isRecipeFetchOnCooldown() -> Bool {
        if let lastFetch = lastRecipeFetch {
            return Date().timeIntervalSince(lastFetch) < recipeFetchInterval
        }
        return false
    }

    func isReportStatusFetchOnCooldown() -> Bool {
        if let lastFetch = lastReportStatusFetchTime {
            return Date().timeIntervalSince(lastFetch) < reportStatusFetchInterval
        }
        return false
    }

    func submitRecipeReport(
        reportType: String,
        recipeName: String,
        category: String,
        recipeID: Int?,
        description: String,
        completion: @escaping @MainActor (Result<RecipeReport, Error>) -> Void
    ) {
        guard isConnected else {
            errorMessage = ErrorType.network.rawValue
            accessibilityAnnouncement = errorMessage
            completion(.failure(NSError(
                domain: "DataManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
            )))
            return
        }

        Task {
            let database = CKContainer(identifier: "iCloud.craftifydb").publicCloudDatabase
            let record = CKRecord(recordType: "PublicRecipeReport")
            let localID = UUID().uuidString
            let timestamp = Date()

            record["localID"] = localID
            record["reportType"] = reportType
            record["recipeName"] = recipeName
            record["category"] = category
            record["recipeID"] = recipeID
            record["description"] = description
            record["timestamp"] = timestamp
            record["status"] = "Pending"

            do {
                let savedRecord = try await database.save(record)
                let report = RecipeReport(
                    id: localID,
                    recordID: savedRecord.recordID.recordName,
                    localID: localID,
                    reportType: reportType,
                    recipeName: recipeName,
                    category: category,
                    recipeID: recipeID,
                    description: description,
                    timestamp: timestamp,
                    status: "Pending"
                )
                accessibilityAnnouncement = "Report submitted successfully"
                lastReportStatusFetchTime = nil
                completion(.success(report))
            } catch {
                let type = errorType(for: error)
                errorMessage = "Failed to submit report: \(type.rawValue)"
                accessibilityAnnouncement = errorMessage
                completion(.failure(error))
            }
        }
    }

    func fetchRecipeReports(
        completion: @escaping @MainActor (Result<[RecipeReport], Error>) -> Void
    ) {
        guard isConnected else {
            errorMessage = ErrorType.network.rawValue
            accessibilityAnnouncement = errorMessage
            completion(.failure(NSError(
                domain: "DataManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
            )))
            return
        }

        if let lastFetch = lastReportStatusFetchTime,
           Date().timeIntervalSince(lastFetch) < reportStatusFetchInterval {
            print("Skipping report fetch; last fetch was less than \(reportStatusFetchInterval) seconds ago.")
            completion(.success([]))
            return
        }

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.craftifydb")
                let userRecordID = try await container.userRecordID()
                let userReference = CKRecord.Reference(recordID: userRecordID, action: .none)
                let predicate = NSPredicate(format: "___createdBy == %@", userReference)
                let query = CKQuery(recordType: "PublicRecipeReport", predicate: predicate)
                let records = try await fetchAllRecords(matching: query, from: container.publicCloudDatabase)
                let reports = records.compactMap(convertRecordToRecipeReport)
                lastReportStatusFetchTime = Date()
                completion(.success(reports))
            } catch {
                let type = errorType(for: error)
                errorMessage = "Failed to fetch reports: \(type.rawValue)"
                accessibilityAnnouncement = errorMessage
                completion(.failure(error))
            }
        }
    }

    func deleteRecipeReport(
        _ report: RecipeReport,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard isConnected else {
            errorMessage = ErrorType.network.rawValue
            accessibilityAnnouncement = errorMessage
            completion(false)
            return
        }

        guard let recordIDString = report.recordID else {
            accessibilityAnnouncement = "Report deleted successfully"
            completion(true)
            return
        }

        Task {
            do {
                let database = CKContainer(identifier: "iCloud.craftifydb").publicCloudDatabase
                _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: recordIDString))
                accessibilityAnnouncement = "Report deleted successfully"
                completion(true)
            } catch let error as CKError where error.code == .unknownItem {
                accessibilityAnnouncement = "Report deleted successfully"
                completion(true)
            } catch {
                let type = errorType(for: error)
                errorMessage = "Failed to delete report: \(type.rawValue)"
                accessibilityAnnouncement = errorMessage
                completion(false)
            }
        }
    }

    func deleteAllRecipeReports(
        reports: [RecipeReport],
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard isConnected else {
            errorMessage = ErrorType.network.rawValue
            accessibilityAnnouncement = errorMessage
            completion(false)
            return
        }

        let recordIDs = reports.compactMap(\.recordID).map { CKRecord.ID(recordName: $0) }
        guard !recordIDs.isEmpty else {
            accessibilityAnnouncement = "All reports deleted successfully"
            completion(true)
            return
        }

        Task {
            do {
                let database = CKContainer(identifier: "iCloud.craftifydb").publicCloudDatabase
                let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: recordIDs)
                for result in deleteResults.values {
                    if case .failure(let error) = result {
                        throw error
                    }
                }
                accessibilityAnnouncement = "All reports deleted successfully"
                completion(true)
            } catch {
                let type = errorType(for: error)
                errorMessage = "Failed to delete all reports: \(type.rawValue)"
                accessibilityAnnouncement = errorMessage
                completion(false)
            }
        }
    }

    func clearCache(completion: @escaping (Bool) -> Void) {
        let fileURL = getCacheDirectory().appendingPathComponent(localCacheFileName())
        do {
            try FileManager.default.removeItem(at: fileURL)
            recipes = []
            cacheClearedMessage = "Cache cleared successfully."
            accessibilityAnnouncement = "Cache cleared successfully."
            completion(true)
        } catch {
            cacheClearedMessage = "Failed to clear cache."
            accessibilityAnnouncement = "Failed to clear cache."
            completion(false)
        }
    }

    func clearAllData(completion: @escaping (Bool) -> Void) {
        clearCache { cacheSuccess in
            self.clearChestsAndLegacyFavorites()
            self.clearRecentSearches()

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

    func fetchConsoleCommands(completion: @escaping @MainActor () -> Void = {}) {
        guard isConnected else {
            errorMessage = ErrorType.network.rawValue
            accessibilityAnnouncement = errorMessage
            completion()
            return
        }

        Task {
            do {
                let database = CKContainer(identifier: "iCloud.craftifydb").publicCloudDatabase
                let query = CKQuery(recordType: "ConsoleCommand", predicate: NSPredicate(value: true))
                let records = try await fetchAllRecords(matching: query, from: database)
                consoleCommands = records.compactMap(convertRecordToConsoleCommand).sorted { $0.name < $1.name }
                completion()
            } catch {
                let type = errorType(for: error)
                errorMessage = type.rawValue
                accessibilityAnnouncement = errorMessage
                completion()
            }
        }
    }

    private func fetchAllRecords(matching query: CKQuery, from database: CKDatabase) async throws -> [CKRecord] {
        var page = try await database.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        var fetchedRecords = records(from: page.matchResults)

        while let cursor = page.queryCursor {
            page = try await database.records(
                continuingMatchFrom: cursor,
                resultsLimit: CKQueryOperation.maximumResults
            )
            fetchedRecords.append(contentsOf: records(from: page.matchResults))
        }

        return fetchedRecords
    }

    private func records(
        from results: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) -> [CKRecord] {
        results.compactMap { recordID, result in
            switch result {
            case .success(let record):
                return record
            case .failure(let error):
                errorMessage = "Error fetching record \(recordID.recordName): \(error.localizedDescription)"
                accessibilityAnnouncement = errorMessage
                return nil
            }
        }
    }

    private func convertRecordToRecipeReport(_ record: CKRecord) -> RecipeReport? {
        guard
            let localID = record["localID"] as? String,
            let reportType = record["reportType"] as? String,
            let recipeName = record["recipeName"] as? String,
            let category = record["category"] as? String,
            let description = record["description"] as? String,
            let timestamp = record["timestamp"] as? Date,
            let status = record["status"] as? String
        else {
            errorMessage = ErrorType.missingFields.rawValue
            accessibilityAnnouncement = errorMessage
            return nil
        }

        return RecipeReport(
            id: localID,
            recordID: record.recordID.recordName,
            localID: localID,
            reportType: reportType,
            recipeName: recipeName,
            category: category,
            recipeID: record["recipeID"] as? Int,
            description: description,
            timestamp: timestamp,
            status: status
        )
    }

    private func convertRecordToConsoleCommand(_ record: CKRecord) -> ConsoleCommand? {
        return ConsoleCommand(from: record)
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
