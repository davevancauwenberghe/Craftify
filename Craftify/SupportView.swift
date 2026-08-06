//
//  SupportView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI
import UIKit

struct SupportView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showClearDataAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var isPrivacyExpanded = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                CraftifyHero(
                    eyebrow: "Help & Control",
                    title: "Support & Privacy",
                    detail: "Contact support, manage Craftify’s downloaded and synced data, and review exactly how the app protects your privacy.",
                    symbol: "hand.raised.fill"
                )

                VStack(alignment: .leading, spacing: 14) {
                    CraftifySectionHeader(
                        title: "Need a Hand?",
                        detail: "Send a message directly to Craftify support.",
                        symbol: "envelope.fill"
                    )
                    Button("Contact Support", systemImage: "envelope.fill", action: contactSupport)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint("Opens the Mail app")
                }
                .padding(18)
                .craftifyCard(cornerRadius: 22)

                CraftifySectionHeader(
                    title: "Data Management",
                    detail: "Choose whether to remove only downloaded content or every piece of Craftify data."
                )

                dataActionCard(
                    title: "Clear Cache",
                    detail: "Removes local recipes and downloaded images. Your iCloud chests, recent searches, and reports stay intact.",
                    symbol: "externaldrive.badge.xmark",
                    actionTitle: "Clear Cache",
                    action: clearCache
                )

                dataActionCard(
                    title: "Clear All Data",
                    detail: "Permanently removes chests, recent searches, CloudKit reports, local recipes, and downloaded images.",
                    symbol: "trash.fill",
                    actionTitle: "Clear All Data",
                    isDestructive: true,
                    action: { showClearDataAlert = true }
                )

                VStack(alignment: .leading, spacing: 14) {
                    CraftifySectionHeader(
                        title: "Privacy Policy",
                        detail: "Craftify asks for no identity or account details and uses no third-party dependencies.",
                        symbol: "lock.shield.fill"
                    )

                    Link(destination: URL(string: "https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/privacy-policy/")!) {
                        Label("View Privacy Policy Online", systemImage: "arrow.up.right.square")
                            .font(.headline)
                    }

                    DisclosureGroup(isExpanded: $isPrivacyExpanded) {
                        PrivacyPolicyContent(horizontalSizeClass: horizontalSizeClass)
                            .padding(.top, 14)
                    } label: {
                        Label("Read Privacy Policy in Craftify", systemImage: "doc.text.fill")
                            .font(.headline)
                    }
                    .onChange(of: isPrivacyExpanded) { _, _ in HapticFeedback.selection() }
                }
                .padding(18)
                .craftifyCard(cornerRadius: 22)
            }
            .craftifyContentWidth(CraftifyLayout.readingMaxWidth)
            .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .navigationTitle("Support & Privacy")
        .navigationBarTitleDisplayMode(.large)
        .craftifyPage()
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
        .alert("Clear All Data", isPresented: $showClearDataAlert) {
            Button("Clear All Data", role: .destructive) {
                dataManager.clearAllData { success in
                    if success {
                        HapticFeedback.notification(.success)
                    } else {
                        HapticFeedback.notification(.error)
                        errorMessage = dataManager.errorMessage ?? "Failed to clear all data. Please try again."
                        showErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your chests, recent searches, CloudKit recipe reports, local recipes, and downloaded images. This action cannot be undone.")
        }
    }

    private func dataActionCard(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                CraftifyIconTile(symbol: symbol, size: 52, destructive: isDestructive)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold())
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if isDestructive {
                Button(role: .destructive, action: action) {
                    Label(actionTitle, systemImage: symbol)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
                .accessibilityHint(detail)
            } else {
                Button(action: action) {
                    Label(actionTitle, systemImage: symbol)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint(detail)
            }
        }
        .padding(18)
        .craftifyCard(cornerRadius: 22)
    }

    private func contactSupport() {
        HapticFeedback.selection()
        if let url = URL(string: "mailto:hello@davevancauwenberghe.be") {
            UIApplication.shared.open(url)
        }
    }

    private func clearCache() {
        dataManager.clearCache { success in
            if success {
                HapticFeedback.notification(.success)
            } else {
                HapticFeedback.notification(.error)
                errorMessage = dataManager.errorMessage ?? "Failed to clear cache. Please try again."
                showErrorAlert = true
            }
        }
    }
}

struct PrivacyPolicyContent: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Policy")
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)

            Text("Last updated: 2 August 2026")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.6)

            Group {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Craftify for Minecraft (\"Craftify\") is developed by Dave Van Cauwenberghe, an individual developer. This Privacy Policy explains how Craftify handles your data. Craftify does not ask you for identity or account details. You choose chest names, so avoid including personal information in them.")
                        .font(.body)
                        .minimumScaleFactor(0.6)

                    Group {
                        Text("1. Data We Collect")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("Craftify stores the minimum data needed to provide its features:")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Chests: Names you enter, chest sizes and ordering, and stored recipe IDs are saved in iCloud to sync your chest room across your devices.")
                            Text("• Legacy Favorites: If you used Favorites in an earlier version, its recipe IDs may remain in iCloud. Craftify no longer reads or imports them, and \"Clear All Data\" removes them.")
                            Text("• Recent Searches: Recipe names when you search for recipes, stored in iCloud to sync across your devices.")
                            Text("• Recipe Reports (Optional): When you report an issue, you may submit a recipe name, category, and description. These are stored in a private CloudKit database (accessible only to you) for the \"My Reports\" feature, allowing you to view and manage your reports across devices.")
                            Text("• Local Recipe and Image Data: Recipes and downloaded CloudKit images are stored on your device for reliable offline access but contain no personal data.")
                        }
                        .font(.body)
                        .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("2. How We Use Your Data")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("We use this data only to make Craftify work:")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Support Chests and Recent Searches by storing their data in iCloud.")
                            Text("• Sync Chests, Recent Searches, and Recipe Reports across your devices using iCloud and CloudKit.")
                            Text("• Store Recipe Reports in CloudKit to improve Craftify’s recipe database.")
                            Text("• Let you view and manage your reports in the \"My Reports\" section using CloudKit sync.")
                        }
                        .font(.body)
                        .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("3. Data Storage and Security")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("Your data is stored securely:")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Chests, Legacy Favorites, and Recent Searches: Chest names, sizes, ordering, recipe IDs (including Favorites saved by earlier versions), and recent recipe names are stored in your iCloud account, protected by Apple’s encryption. We cannot access this data.")
                            Text("• Recipe Reports: Stored privately in a CloudKit database (accessible only to you via your iCloud account) for the \"My Reports\" feature.")
                            Text("• Local Recipe Data: Stored on your device and contains no personal information.")
                            Text("• Downloaded Recipe Images: Stored persistently on your device, excluded from device backups, and contain no personal information.")
                        }
                        .font(.body)
                        .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("4. Data Sharing")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("Craftify does not share your data with third parties. The app uses no third-party dependencies, and all data stays in your iCloud account or in a private CloudKit database (for Recipe Reports, accessible only to you).")
                            .font(.body)
                            .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("5. Usage Data")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("Craftify does not collect personalized usage data. We use Apple’s CloudKit to fetch recipes and manage reports in our CloudKit database. The CloudKit Console provides only anonymized metadata, like device model (e.g., iPhone 15) or iOS version, which is not linked to you or your Apple ID. This is used solely to monitor app performance and compatibility.")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        Text("Network Connectivity Monitoring:")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)

                        Text("Craftify monitors your device’s network connectivity status (e.g., Wi-Fi, cellular, or offline) to enhance your experience. This allows us to disable syncing when you’re offline, show connection status in the app, and auto-retry syncing when you reconnect. We do not collect or store any network data, and this information is used only locally on your device to manage app features. It is not shared with us or any third parties.")
                            .font(.body)
                            .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("6. Your Control Over Your Data")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("You can manage your data in Craftify:")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Chests: Swipe a chest or a stored recipe to delete it. Use Edit to rearrange chests.")
                            Text("• Recent Searches: Tap \"Clear All\" in the Search tab to remove all recent searches.")
                            Text("• Clear All Data: Tap \"Clear All Data\" in this section to delete Chests, legacy Favorites, Recent Searches, CloudKit Recipe Reports, local recipe data, and downloaded images.")
                            Text("• Clear Cache: Use \"Clear Cache\" in this section to remove local recipe data and downloaded images while keeping iCloud data like Chests.")
                            Text("• Recipe Reports: In the \"My Reports\" section of \"Report Issue\", you can view and delete your reports, which also removes them from CloudKit.")
                        }
                        .font(.body)
                        .minimumScaleFactor(0.6)

                        Text("After clearing all data, nothing remains in the app, iCloud, or CloudKit tied to you.")
                            .font(.body)
                            .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("7. Children’s Privacy")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("Craftify is rated 4+ and suitable for young children. We do not collect personally identifiable information from children under 13, in compliance with the Children’s Online Privacy Protection Act (COPPA, 16 CFR Part 312) in the U.S., the General Data Protection Regulation (GDPR, Regulation (EU) 2016/679) in the EU, and other applicable laws worldwide.")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        Text("Under GDPR Article 8, processing personal data of children under 16 (or lower, depending on the EU country) requires parental consent if based on consent. Craftify does not collect personal data as defined by GDPR, and our data processing is based on legitimate interests for app functionality, not consent, so parental consent is not required.")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        Text("Parents or guardians can manage a child’s data by:")
                            .font(.body)
                            .minimumScaleFactor(0.6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Using the \"Clear All Data\" button in the Support & Privacy section to remove all data from local storage, iCloud, and CloudKit.")
                        }
                        .font(.body)
                        .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("8. Changes to This Policy")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("We may update this policy if Craftify changes. Check the \"Last Updated\" date for the latest version.")
                            .font(.body)
                            .minimumScaleFactor(0.6)
                    }

                    Group {
                        Text("9. Contact Us")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)

                        Text("For questions, contact us through the \"Contact Support\" button.")
                            .font(.body)
                            .minimumScaleFactor(0.6)
                    }

                    Text("Thank you for using Craftify!")
                        .font(.body)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.6)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 8)
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
