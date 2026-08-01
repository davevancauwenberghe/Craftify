//
//  CraftImageStore.swift
//  Craftify
//
//  CloudKit-backed shared image library with bundled and disk fallbacks.
//

import Foundation
import SwiftUI
import UIKit
@preconcurrency import CloudKit

enum CraftImageAssetKey {
    static let recordType = "CraftImageAsset"
    static let assetKeyField = "assetKey"
    static let fileField = "file"
    static let versionField = "version"

    static func recordName(for assetKey: String) -> String {
        let encoded = Data(assetKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "asset-\(encoded)"
    }
}

@MainActor
final class CraftImageStore: ObservableObject {
    static let shared = CraftImageStore()

    private let database: CKDatabase
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let imageDirectory: URL
    private let legacyCacheDirectory: URL
    private let imageCache = NSCache<NSString, UIImage>()
    private var loadingKeys: Set<String> = []
    private var lastChecked: [String: Date] = [:]
    private var storageGeneration = 0

    private static let versionDefaultsPrefix = "craft-image.version."
    private let queryBatchSize = 100
    private let refreshInterval: TimeInterval = 15 * 60

    init(
        containerIdentifier: String = "iCloud.craftifydb",
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        storageDirectory: URL? = nil,
        legacyCacheDirectory: URL? = nil
    ) {
        self.database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        self.fileManager = fileManager
        self.defaults = defaults

        let applicationSupportRoot = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        self.imageDirectory = storageDirectory ?? applicationSupportRoot
            .appendingPathComponent("CraftImageAssets", isDirectory: true)

        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.legacyCacheDirectory = legacyCacheDirectory ?? cachesRoot
            .appendingPathComponent("CraftImageAssets", isDirectory: true)

        prepareStorage()
        imageCache.countLimit = 300
    }

    func image(for assetKey: String) -> UIImage? {
        let cacheKey = assetKey as NSString
        if let image = imageCache.object(forKey: cacheKey) {
            return image
        }

        if let image = UIImage(contentsOfFile: cachedFileURL(for: assetKey).path) {
            imageCache.setObject(image, forKey: cacheKey)
            return image
        }

        return UIImage(named: assetKey)
    }

    func prefetch(recipes: [Recipe]) {
        let keys = Self.imageKeys(in: recipes)
        Task { [weak self] in
            await self?.synchronize(keys: keys)
        }
    }

    func load(_ assetKey: String) async {
        let trimmed = assetKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await synchronize(keys: [assetKey])
    }

    func refresh(recipes: [Recipe]) async {
        await synchronize(keys: Self.imageKeys(in: recipes), force: true)
    }

    static func imageKeys(in recipes: [Recipe]) -> Set<String> {
        var keys: Set<String> = []

        func insert(_ value: String?) {
            guard let value,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            keys.insert(value)
        }

        for recipe in recipes {
            insert(recipe.image)
            insert(recipe.imageremark)

            let ingredientSets = [
                recipe.ingredients,
                recipe.alternateIngredients ?? [],
                recipe.alternateIngredients1 ?? [],
                recipe.alternateIngredients2 ?? [],
                recipe.alternateIngredients3 ?? []
            ]

            for ingredientSet in ingredientSets {
                ingredientSet.forEach { insert($0) }
            }
        }

        return keys
    }

    private func synchronize(keys: Set<String>, force: Bool = false) async {
        let generation = storageGeneration
        let usableKeys = Set(keys.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        let now = Date()
        let dueKeys = usableKeys.filter { key in
            guard !loadingKeys.contains(key) else { return false }
            if force { return true }
            guard let checked = lastChecked[key] else { return true }
            return now.timeIntervalSince(checked) >= refreshInterval
        }

        guard !dueKeys.isEmpty else { return }

        let requestedKeys = Set(dueKeys)
        loadingKeys.formUnion(requestedKeys)
        defer { loadingKeys.subtract(requestedKeys) }

        let sortedKeys = requestedKeys.sorted()
        for start in stride(from: 0, to: sortedKeys.count, by: queryBatchSize) {
            guard generation == storageGeneration else { return }
            let end = min(start + queryBatchSize, sortedKeys.count)
            let batch = Array(sortedKeys[start..<end])
            await synchronize(batch: batch, generation: generation)
        }
    }

    private func synchronize(batch: [String], generation: Int) async {
        guard generation == storageGeneration else { return }
        let predicate = NSPredicate(
            format: "%K IN %@",
            CraftImageAssetKey.assetKeyField,
            batch
        )
        let metadataQuery = CKQuery(
            recordType: CraftImageAssetKey.recordType,
            predicate: predicate
        )

        do {
            let metadataRecords = try await fetchAllRecords(
                matching: metadataQuery,
                desiredKeys: [
                    CraftImageAssetKey.assetKeyField,
                    CraftImageAssetKey.versionField
                ]
            )
            guard generation == storageGeneration else { return }

            let metadata = metadataRecords.reduce(into: [String: Int64]()) { result, record in
                guard let key = record[CraftImageAssetKey.assetKeyField] as? String else {
                    return
                }
                let version = record[CraftImageAssetKey.versionField] as? Int64 ?? 1
                result[key] = max(result[key] ?? 0, version)
            }

            let returnedKeys = Set(metadata.keys)
            var cacheChanged = false

            for key in batch where !returnedKeys.contains(key) && localVersion(for: key) > 0 {
                removeCachedRemoteImage(for: key)
                cacheChanged = true
            }

            let outdatedKeys = metadata.compactMap { key, remoteVersion -> String? in
                let hasValidFile = UIImage(contentsOfFile: cachedFileURL(for: key).path) != nil
                return localVersion(for: key) < remoteVersion || !hasValidFile ? key : nil
            }

            if !outdatedKeys.isEmpty {
                let assetPredicate = NSPredicate(
                    format: "%K IN %@",
                    CraftImageAssetKey.assetKeyField,
                    outdatedKeys
                )
                let assetQuery = CKQuery(
                    recordType: CraftImageAssetKey.recordType,
                    predicate: assetPredicate
                )
                let assetRecords = try await fetchAllRecords(
                    matching: assetQuery,
                    desiredKeys: [
                        CraftImageAssetKey.assetKeyField,
                        CraftImageAssetKey.fileField,
                        CraftImageAssetKey.versionField
                    ]
                )
                guard generation == storageGeneration else { return }

                for record in assetRecords {
                    if try store(record: record) {
                        cacheChanged = true
                    }
                }
            }

            let checkedAt = Date()
            batch.forEach { lastChecked[$0] = checkedAt }

            if cacheChanged {
                objectWillChange.send()
            }
        } catch {
            let checkedAt = Date()
            batch.forEach { lastChecked[$0] = checkedAt }
            print("Craft image sync failed: \(error.localizedDescription)")
        }
    }

    private func fetchAllRecords(
        matching query: CKQuery,
        desiredKeys: [CKRecord.FieldKey]
    ) async throws -> [CKRecord] {
        var page = try await database.records(
            matching: query,
            desiredKeys: desiredKeys,
            resultsLimit: CKQueryOperation.maximumResults
        )
        var records = successfulRecords(from: page.matchResults)

        while let cursor = page.queryCursor {
            page = try await database.records(
                continuingMatchFrom: cursor,
                desiredKeys: desiredKeys,
                resultsLimit: CKQueryOperation.maximumResults
            )
            records.append(contentsOf: successfulRecords(from: page.matchResults))
        }

        return records
    }

    private func successfulRecords(
        from results: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) -> [CKRecord] {
        results.compactMap { _, result in
            try? result.get()
        }
    }

    @discardableResult
    private func store(record: CKRecord) throws -> Bool {
        guard let assetKey = record[CraftImageAssetKey.assetKeyField] as? String,
              let asset = record[CraftImageAssetKey.fileField] as? CKAsset,
              let sourceURL = asset.fileURL else {
            return false
        }

        let data = try Data(contentsOf: sourceURL)
        guard let image = UIImage(data: data) else {
            throw CraftImageStoreError.invalidImageData
        }

        try data.write(to: cachedFileURL(for: assetKey), options: .atomic)
        imageCache.setObject(image, forKey: assetKey as NSString)

        let version = record[CraftImageAssetKey.versionField] as? Int64 ?? 1
        defaults.set(Int(version), forKey: versionDefaultsKey(for: assetKey))
        return true
    }

    private func cachedFileURL(for assetKey: String) -> URL {
        imageDirectory.appendingPathComponent(
            CraftImageAssetKey.recordName(for: assetKey),
            isDirectory: false
        )
    }

    private func localVersion(for assetKey: String) -> Int64 {
        Int64(defaults.integer(forKey: versionDefaultsKey(for: assetKey)))
    }

    private func versionDefaultsKey(for assetKey: String) -> String {
        Self.versionDefaultsPrefix + CraftImageAssetKey.recordName(for: assetKey)
    }

    func clearDownloadedImages() throws {
        storageGeneration += 1
        loadingKeys.removeAll()
        lastChecked.removeAll()
        imageCache.removeAllObjects()

        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.versionDefaultsPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }

        objectWillChange.send()
        defer { try? createImageDirectory() }

        if fileManager.fileExists(atPath: imageDirectory.path) {
            try fileManager.removeItem(at: imageDirectory)
        }
        if legacyCacheDirectory != imageDirectory,
           fileManager.fileExists(atPath: legacyCacheDirectory.path) {
            try fileManager.removeItem(at: legacyCacheDirectory)
        }

        try createImageDirectory()
        objectWillChange.send()
    }

    private func prepareStorage() {
        do {
            try createImageDirectory()
            migrateLegacyImagesIfNeeded()
        } catch {
            print("Unable to prepare persistent image storage: \(error.localizedDescription)")
        }
    }

    private func createImageDirectory() throws {
        try fileManager.createDirectory(
            at: imageDirectory,
            withIntermediateDirectories: true
        )

        var directoryURL = imageDirectory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try directoryURL.setResourceValues(resourceValues)
        } catch {
            print("Unable to exclude downloaded images from backup: \(error.localizedDescription)")
        }
    }

    private func migrateLegacyImagesIfNeeded() {
        guard legacyCacheDirectory != imageDirectory,
              fileManager.fileExists(atPath: legacyCacheDirectory.path),
              let legacyFiles = try? fileManager.contentsOfDirectory(
                at: legacyCacheDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        for sourceURL in legacyFiles {
            let destinationURL = imageDirectory.appendingPathComponent(
                sourceURL.lastPathComponent,
                isDirectory: false
            )

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: sourceURL)
                } else {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                }
            } catch {
                print(
                    "Unable to migrate downloaded image \(sourceURL.lastPathComponent): "
                    + error.localizedDescription
                )
            }
        }

        if let remainingFiles = try? fileManager.contentsOfDirectory(
            at: legacyCacheDirectory,
            includingPropertiesForKeys: nil
        ), remainingFiles.isEmpty {
            try? fileManager.removeItem(at: legacyCacheDirectory)
        }
    }

    private func removeCachedRemoteImage(for assetKey: String) {
        try? fileManager.removeItem(at: cachedFileURL(for: assetKey))
        imageCache.removeObject(forKey: assetKey as NSString)
        defaults.removeObject(forKey: versionDefaultsKey(for: assetKey))
    }
}

private enum CraftImageStoreError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        "CloudKit returned an invalid image file."
    }
}

@MainActor
struct CraftImage: View {
    @ObservedObject private var store: CraftImageStore
    let key: String
    let fallbackSystemName: String

    init(
        key: String,
        fallbackSystemName: String = "photo",
        store: CraftImageStore = .shared
    ) {
        self.key = key
        self.fallbackSystemName = fallbackSystemName
        _store = ObservedObject(wrappedValue: store)
    }

    var body: some View {
        Group {
            if let image = store.image(for: key) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: key) {
            await store.load(key)
        }
    }
}
