//
//  SupportView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI

struct SupportView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showClearDataAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Support")) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let supportEmail = "hello@davevancauwenberghe.be"
                        if let url = URL(string: "mailto:\(supportEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        buttonStyle(title: "Contact Support", systemImage: "envelope.fill")
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Contact Support")
                    .accessibilityHint("Opens the mail app to contact support")
                }

                Section(header: Text("Data Management")) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showClearDataAlert = true
                    }) {
                        buttonStyle(title: "Clear All Data", systemImage: "trash.fill", foregroundColor: .red)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Clear All Data")
                    .accessibilityHint("Clears all local and iCloud data, including favorites, recent searches, and recipe reports")

                    Text("This will permanently delete all your favorites, recent searches (stored in iCloud), recipe reports (stored in CloudKit), and the local recipe cache.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                        .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                        .accessibilityLabel("Clear All Data Note")
                        .accessibilityHint("This will permanently delete all your favorites, recent searches, recipe reports, and the local recipe cache.")

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dataManager.clearCache { success in
                            if !success {
                                errorMessage = dataManager.errorMessage ?? "Failed to clear cache. Please try again."
                                showErrorAlert = true
                            }
                        }
                    }) {
                        buttonStyle(title: "Clear Cache", systemImage: "trash.fill", foregroundColor: .red)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Clear Cache")
                    .accessibilityHint("Clears the cached Minecraft recipes, keeping iCloud data like favorites")

                    Text("This will permanently delete the local recipe cache, keeping iCloud data like favorites and recent searches.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                        .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                        .accessibilityLabel("Clear Cache Note")
                        .accessibilityHint("This will permanently delete the local recipe cache, keeping iCloud data like favorites and recent searches.")
                }

                Section(header: Text("Privacy")) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if let url = URL(string: "https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/privacy-policy/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        buttonStyle(title: "View Privacy Policy Online", systemImage: "safari.fill")
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("View Privacy Policy Online")
                    .accessibilityHint("Opens the privacy policy in your web browser")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Policy")
                            .font(.title2)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)

                        Text("Last updated: 20 May 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Craftify for Minecraft (\"Craftify\") is developed by Dave Van Cauwenberghe, an individual developer. This Privacy Policy explains how Craftify handles your data. We are committed to protecting your privacy and do not collect any personal information.")
                                    .font(.body)

                                Group {
                                    Text("1. Data We Collect")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("Craftify collects minimal data to provide its features, none of which identifies you:")
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Favorites: Recipe IDs when you mark a recipe as a favorite, stored in iCloud to sync across your devices.")
                                        Text("• Recent Searches: Recipe names when you search for recipes, stored in iCloud to sync across your devices.")
                                        Text("• Recipe Reports (Optional): When you report an issue, you may submit a recipe name, category, and description. These are stored in a private CloudKit database (accessible only to you) for the \"My Reports\" feature, allowing you to view and manage your reports across devices.")
                                        Text("• Local Recipe Cache: Recipes are cached on your device for offline access but contain no personal data.")
                                    }
                                    .font(.body)
                                }

                                Group {
                                    Text("2. How We Use Your Data")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("We use this data only to make Craftify work:")
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Support the Favorites and Recent Searches features by storing data in iCloud.")
                                        Text("• Sync Favorites, Recent Searches, and Recipe Reports across your devices using CloudKit.")
                                        Text("• Store Recipe Reports in CloudKit to improve Craftify’s recipe database.")
                                        Text("• Let you view and manage your reports in the \"My Reports\" section using CloudKit sync.")
                                    }
                                    .font(.body)
                                }

                                Group {
                                    Text("3. Data Storage and Security")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("Your data is stored securely:")
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Favorites and Recent Searches: Stored in your iCloud account, protected by Apple’s encryption. We cannot access this data.")
                                        Text("• Recipe Reports: Stored privately in a CloudKit database (accessible only to you via your iCloud account) for the \"My Reports\" feature.")
                                        Text("• Local Recipe Cache: Stored on your device with no personal information.")
                                    }
                                    .font(.body)
                                }

                                Group {
                                    Text("4. Data Sharing")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("Craftify does not share your data with third parties. The app uses no third-party dependencies, and all data stays in your iCloud account or in a private CloudKit database (for Recipe Reports, accessible only to you).")
                                        .font(.body)
                                }

                                Group {
                                    Text("5. Usage Data")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("Craftify does not collect personalized usage data. We use Apple’s CloudKit to fetch recipes and manage reports in our CloudKit database. The CloudKit Console provides only anonymized metadata, like device model (e.g., iPhone 15) or iOS version, which is not linked to you or your Apple ID. This is used solely to monitor app performance and compatibility.")
                                        .font(.body)

                                    Text("Network Connectivity Monitoring:")
                                        .font(.subheadline)
                                        .fontWeight(.bold)

                                    Text("Craftify monitors your device’s network connectivity status (e.g., Wi-Fi, cellular, or offline) to enhance your experience. This allows us to disable syncing when you’re offline, show connection status in the app, and auto-retry syncing when you reconnect. We do not collect or store any network data, and this information is used only locally on your device to manage app features. It is not shared with us or any third parties.")
                                        .font(.body)
                                }

                                Group {
                                    Text("6. Your Control Over Your Data")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("You can manage your data in Craftify:")
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Favorites: Untoggle the heart icon to remove a recipe from Favorites.")
                                        Text("• Recent Searches: Tap \"Clear All\" in the Search tab to remove all recent searches.")
                                        Text("• Clear All Data: Tap \"Clear All Data\" in this section to delete everything, including Favorites, Recent Searches, Recipe Reports, and the local cache.")
                                        Text("• Clear Cache: Use \"Clear Cache\" in this section to remove the local cache, keeping iCloud data like Favorites.")
                                        Text("• Recipe Reports: In the \"My Reports\" section of \"Report Issue\", you can view and delete your reports, which also removes them from CloudKit.")
                                    }
                                    .font(.body)

                                    Text("After clearing all data, nothing remains in the app, iCloud, or CloudKit tied to you.")
                                        .font(.body)
                                }

                                Group {
                                    Text("7. Children’s Privacy")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("Craftify is rated 4+ and suitable for young children. We do not collect personally identifiable information from children under 13, in compliance with the Children’s Online Privacy Protection Act (COPPA, 16 CFR Part 312) in the U.S., the General Data Protection Regulation (GDPR, Regulation (EU) 2016/679) in the EU, and other applicable laws worldwide.")
                                        .font(.body)

                                    Text("Under GDPR Article 8, processing personal data of children under 16 (or lower, depending on the EU country) requires parental consent if based on consent. Craftify does not collect personal data as defined by GDPR, and our data processing is based on legitimate interests for app functionality, not consent, so parental consent is not required.")
                                        .font(.body)

                                    Text("Parents or guardians can manage a child’s data by:")
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• Using the \"Clear All Data\" button in the Support & Privacy section to remove all data from local storage, iCloud, and CloudKit.")
                                    }
                                    .font(.body)
                                }

                                Group {
                                    Text("8. Changes to This Policy")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("We may update this policy if Craftify changes. Check the \"Last Updated\" date for the latest version.")
                                        .font(.body)
                                }

                                Group {
                                    Text("9. Contact Us")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .accessibilityAddTraits(.isHeader)

                                    Text("For questions, contact us through the \"Contact Support\" button.")
                                        .font(.body)
                                }

                                Text("Thank you for using Craftify!")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 300)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Privacy Policy for Craftify")
                        .accessibilityValue("Last updated 20 May 2025. Craftify does not collect personal information. Data includes Favorites, Recent Searches, and Recipe Reports stored in iCloud and CloudKit for syncing. Network connectivity is monitored locally to manage syncing, not shared. Data is used for app features, with no third-party sharing. Anonymized CloudKit metadata is used for performance. You can clear all data. Craftify is safe for kids under 13, complying with COPPA and GDPR.")
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Support & Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
            .background(Color(UIColor.systemGroupedBackground))
            .alert(isPresented: $showClearDataAlert) {
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                return Alert(
                    title: Text("Clear All Data"),
                    message: Text("Are you sure? This will remove all your favorites, recent searches, recipe reports, and the local recipe cache. This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear All Data")) {
                        dataManager.clearAllData { success in
                            if !success {
                                errorMessage = dataManager.errorMessage ?? "Failed to clear all data. Please try again."
                                showErrorAlert = true
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
        }
    }

    private func buttonStyle(title: String, systemImage: String, foregroundColor: Color = Color.userAccentColor) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(foregroundColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
    }
}
