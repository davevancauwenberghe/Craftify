//
//  NotificationManager.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 25/06/2025.
//

import Foundation
import CloudKit
import UserNotifications
import UIKit

/// Protocol defining the interface for managing APNs permissions
/// and CloudKit query subscriptions for report status updates.
protocol NotificationManaging {
    /// Ask the user for notification permissions (.alert, .badge, .sound).
    /// - Parameter completion: Called on the main thread with `true` if granted.
    func requestUserPermissions(completion: @escaping (Bool) -> Void)
    
    /// Register with APNs to receive a device token.
    func registerForRemoteNotifications()
    
    /// Create a CloudKit subscription so that the user receives
    /// a push notification whenever a `PublicRecipeReport` they created
    /// is updated.
    /// - Parameters:
    ///   - userRecordID: The current user’s record ID.
    ///   - completion: Called on the main thread with .success or .failure.
    func createReportStatusSubscription(
        for userRecordID: CKRecord.ID,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    /// Delete the CloudKit subscription that was set up for report status updates.
    /// - Parameters:
    ///   - userRecordID: The current user’s record ID.
    ///   - completion: Called on the main thread with .success or .failure.
    func deleteReportStatusSubscription(
        for userRecordID: CKRecord.ID,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

/// Concrete implementation of `NotificationManaging`
/// that uses CloudKit and UserNotifications.
final class NotificationManager: NSObject, ObservableObject {
    private let container: CKContainer
    private let publicDB: CKDatabase

    /// Initialize with your CloudKit container identifier.
    /// Default is the production container “iCloud.craftifydb”.
    init(containerIdentifier: String = "iCloud.craftifydb") {
        container = CKContainer(identifier: containerIdentifier)
        publicDB = container.publicCloudDatabase
        super.init()
    }

    func requestUserPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func createReportStatusSubscription(
        for userRecordID: CKRecord.ID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let subscriptionID = "ReportStatusChanges_\(userRecordID.recordName)"
        let predicate = NSPredicate(format: "creatorUserRecordID == %@", userRecordID)
        let subscription = CKQuerySubscription(
            recordType: "PublicRecipeReport",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]
        )

        let info = CKSubscription.NotificationInfo()
        info.title = "Craftify Update"
        info.alertBody = "Your report status changed."
        info.soundName = "default"
        subscription.notificationInfo = info

        publicDB.save(subscription) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    func deleteReportStatusSubscription(
        for userRecordID: CKRecord.ID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let subscriptionID = "ReportStatusChanges_\(userRecordID.recordName)"
        publicDB.delete(withSubscriptionID: subscriptionID) { _, error in
            DispatchQueue.main.async {
                // Treat “unknownItem” as success (subscription didn’t exist)
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}
