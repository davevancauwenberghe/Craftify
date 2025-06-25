//
//  SupportView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI
import CloudKit
import UIKit

struct SupportView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var showClearDataAlert = false

    /// Your new NotificationManager
    private let notificationManager = NotificationManager()

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top:    horizontalSizeClass == .regular ? 12 : 8,
            leading:horizontalSizeClass == .regular ? 16 : 12,
            bottom: horizontalSizeClass == .regular ? 12 : 8,
            trailing:horizontalSizeClass == .regular ? 16 : 12
        )
    }

    var body: some View {
        List {
            Section("Support") {
                contactSupportButton

                #if os(iOS)
                Toggle(isOn: $notificationsEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text("Report Status Notifications")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                }
                .listRowInsets(rowInsets)
                .accessibilityLabel("Report Status Notifications")
                .accessibilityHint("Toggle to enable or disable notifications for report status changes")
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        // 1. Ask for permission
                        notificationManager.requestUserPermissions { granted in
                            guard granted else {
                                DispatchQueue.main.async { notificationsEnabled = false }
                                return
                            }
                            // 2. Register for APNs
                            notificationManager.registerForRemoteNotifications()
                            // 3. Fetch the iCloud user record ID
                            CKContainer(identifier: "iCloud.craftifydb")
                                .fetchUserRecordID { recordID, error in
                                    DispatchQueue.main.async {
                                        guard let recordID = recordID, error == nil else {
                                            notificationsEnabled = false
                                            return
                                        }
                                        // 4. Create the CloudKit subscription
                                        notificationManager.createReportStatusSubscription(
                                            for: recordID
                                        ) { result in
                                            if case .failure = result {
                                                notificationsEnabled = false
                                            }
                                        }
                                    }
                                }
                        }
                    } else {
                        // On disable: fetch ID and delete the subscription
                        CKContainer(identifier: "iCloud.craftifydb")
                            .fetchUserRecordID { recordID, error in
                                DispatchQueue.main.async {
                                    guard let recordID = recordID, error == nil else { return }
                                    notificationManager.deleteReportStatusSubscription(
                                        for: recordID
                                    ) { _ in /* ignore result */ }
                                }
                            }
                    }
                }
                #endif
            }

            Section("Data Management") {
                clearAllDataButton

                Text(
                    "This will permanently delete all your favorites, recent searches " +
                    "(stored in iCloud), recipe reports (stored in CloudKit), and the local recipe cache."
                )
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .padding(.bottom, 8)
                .accessibilityLabel("Clear All Data Note")
                .accessibilityHint("This will permanently delete favorites, recent searches, recipe reports, and local cache")

                clearCacheButton

                Text(
                    "This will permanently delete the local recipe cache, keeping iCloud data " +
                    "like favorites and recent searches."
                )
                .font(horizontalSizeClass == .regular ? .body : .subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .padding(.top, 8)
                .accessibilityLabel("Clear Cache Note")
                .accessibilityHint("Deletes local recipe cache but retains iCloud data")
            }

            Section("Privacy") {
                viewPolicyButton

                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .bold()
                    Text("Last updated: 20 May 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("""
Craftify for Minecraft ("Craftify") is developed by Dave Van Cauwenberghe, an individual developer. This Privacy Policy explains how Craftify handles your data. We are committed to protecting your privacy and do not collect any personal information.

1. Data We Collect
• Favorites: Recipe IDs marked as favorites, stored in iCloud.
• Recent Searches: Recipe names you search for, stored in iCloud.
• Recipe Reports: Optional issue reports stored privately in your CloudKit.
• Local Cache: Cached recipes for offline use, containing no personal data.

2. How We Use Your Data
• Sync favorites and searches via iCloud.
• Store reports in CloudKit for “My Reports” feature.
• Send notifications on report status changes (if enabled).

3. Data Storage & Security
• iCloud storage is encrypted and private.
• CloudKit reports accessible only to you.
• Local cache resides on your device only.
• Notifications sent securely via APNS.

4. Data Sharing
• No third-party sharing; all data stays in your iCloud/CloudKit.

5. Usage Data
• No personalized analytics collected.
• Anonymized CloudKit metadata used only for performance monitoring.

6. Your Control
• Remove favorites in-app.
• Clear searches in Search tab.
• “Clear All Data” removes everything.
• “Clear Cache” keeps iCloud data intact.
• Disable notifications any time.

7. Children’s Privacy
• Rated 4+, no personal data from children under 13.
• Complies with COPPA, GDPR.

8. Changes to Policy
• Updates posted with new “Last updated” date.

9. Contact Us
• Use “Contact Support” button for questions.

Thank you for using Craftify!
""")
                                .font(.body)
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 300)
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Support & Privacy")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .alert(isPresented: $showClearDataAlert) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return Alert(
                title: Text("Clear All Data"),
                message: Text("Are you sure? This will remove all your favorites, recent searches, recipe reports, and the local recipe cache. This action cannot be undone."),
                primaryButton: .destructive(Text("Clear All Data")) {
                    dataManager.clearAllData { success in
                        if !success {
                            dataManager.errorMessage = "Failed to clear all data. Please try again."
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: Subviews

    private var contactSupportButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let email = "hello@davevancauwenberghe.be"
            if let url = URL(string: "mailto:\(email)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.title2)
                Text("Contact Support")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
        }
        .listRowInsets(rowInsets)
        .accessibilityLabel("Contact Support")
        .accessibilityHint("Opens the mail app to contact support")
    }

    private var clearAllDataButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showClearDataAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("Clear All Data")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
        }
        .listRowInsets(rowInsets)
        .accessibilityLabel("Clear All Data")
        .accessibilityHint("Clears all local and iCloud data, including favorites, recent searches, and recipe reports")
    }

    private var clearCacheButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dataManager.clearCache { success in
                if !success {
                    dataManager.errorMessage = "Failed to clear cache. Please try again."
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("Clear Cache")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
        }
        .listRowInsets(rowInsets)
        .accessibilityLabel("Clear Cache")
        .accessibilityHint("Clears the cached Minecraft recipes, keeping iCloud data like favorites")
    }

    private var viewPolicyButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let url = URL(string: "https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/privacy-policy/") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .font(.title2)
                Text("View Privacy Policy Online")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
        }
        .listRowInsets(rowInsets)
        .accessibilityLabel("View Privacy Policy Online")
        .accessibilityHint("Opens the privacy policy in your web browser")
    }
}
