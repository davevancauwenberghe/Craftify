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

    var body: some View {
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

                Text("This will permanently delete all your favorites, recent searches (stored in iCloud), recipe reports (stored locally and in CloudKit), and the local recipe cache.")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                    .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                    .accessibilityLabel("Clear All Data Note")
                    .accessibilityHint("This will permanently delete all your favorites, recent searches, recipe reports, and the local recipe cache.")
            }

            Section(header: Text("Privacy")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text("Last updated: 19 May 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Craftify for Minecraft (\"Craftify\") is developed by Dave Van Cauwenberghe, an individual developer. This Privacy Policy explains how Craftify handles your data, ensuring transparency and compliance with applicable laws and App Store guidelines. We are committed to protecting your privacy. Craftify does not collect any personal information.")
                                .font(.body)

                            Group {
                                Text("1. Data We Collect")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Craftify collects minimal data to provide its functionality, none of which is personally identifiable:")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• **Favorite Recipes**: Recipe IDs when you mark a recipe as a favorite, stored in iCloud for syncing across your devices.")
                                    Text("• **Recent Searches**: Recipe names when you search for and view recipes, stored in iCloud for syncing across your devices.")
                                    Text("• **Recipe Reports (Optional)**: When you use the \"Report Issue\" feature, you may submit the recipe name, category, and a description to help us improve the app. This data is stored anonymously in CloudKit and locally on your device for the \"My Reports\" feature, which allows you to view and manage your submissions. Reports are not linked to your identity or any personal information.")
                                }
                                .font(.body)

                                Text("We do not collect any personally identifiable information, such as your name, email address, location, or other personal details. Recipe reports are anonymous and cannot be traced back to you, even though CloudKit includes a system-generated creator field that we do not access or use.")
                                    .font(.body)
                            }

                            Group {
                                Text("2. How We Use Your Data")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("We use this data solely to provide Craftify’s core functionality:")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• Enable the Favorites and Recent Searches features by storing recipe IDs and names in iCloud.")
                                    Text("• Sync Favorites and Recent Searches across your devices via iCloud.")
                                    Text("• Store recipe reports in CloudKit to review and improve Craftify’s recipe database.")
                                    Text("• Allow you to view and manage your submitted reports in the \"My Reports\" section using local storage.")
                                }
                                .font(.body)

                                Text("We do not use your data for personalization, profiling, advertising, or any other purpose beyond app functionality.")
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
                                    Text("• **Favorites and Recent Searches**: Stored in your iCloud account using Apple’s iCloud Key-Value Store (`NSUbiquitousKeyValueStore`). This data is tied to your Apple ID, accessible only on your devices, and protected by Apple’s encryption. We cannot access your iCloud data.")
                                    Text("• **Recipe Reports**: Stored anonymously in the public CloudKit database (`iCloud.craftifydb`). Reports are not linked to your Apple ID or any personally identifiable information. A local copy is stored on your device in the app’s private storage to enable the \"My Reports\" feature, allowing you to view and delete your reports.")
                                    Text("• **Local Recipe Cache**: Recipes are cached locally on your device for offline access but contain no personal information.")
                                }
                                .font(.body)
                            }

                            Group {
                                Text("4. Data Sharing")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Craftify does not share your data with third parties. The app uses no third-party dependencies, and all data remains in your iCloud account, on your device, or in the public CloudKit database (for anonymous recipe reports).")
                                    .font(.body)
                            }

                            Group {
                                Text("5. Usage Data")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Craftify does not collect personalized usage data. We use Apple’s CloudKit to fetch recipes from a public database (`iCloud.craftifydb`). The CloudKit Console provides only anonymized metadata, such as device model (e.g., iPhone 15) or iOS version, which is not linked to you or your Apple ID. This is used solely to monitor app performance and compatibility.")
                                    .font(.body)
                            }

                            Group {
                                Text("6. Your Control Over Your Data")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("You have full control over your data in Craftify:")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• **Favorites Recipes**: Untoggle the heart icon on a recipe to remove it from Favorites.")
                                    Text("• **Recent Searches**: Tap \"Clear All\" in the Search tab to remove all recent searches.")
                                    Text("• **Clear All Data**: Tap \"Clear All Data\" in this Support & Privacy section (via More > About Craftify) to delete all data, including the local recipe cache, Favorites, Recent Searches, and recipe reports (both locally and from CloudKit).")
                                    Text("• **Clear Cache**: Use \"Clear Cache\" in the More tab to remove only the local recipe cache and reports, without affecting iCloud data like Favorites and Recent Searches.")
                                    Text("• **Recipe Reports**: In the \"My Reports\" section of the \"Report Issue\" feature, you can view and delete your submitted reports, which also removes them from CloudKit.")
                                }
                                .font(.body)

                                Text("After using \"Clear All Data,\" no data remains tied to you in the app, iCloud, or CloudKit. We cannot access or delete your iCloud data directly; deleting the app after clearing data ensures no further syncing occurs.")
                                    .font(.body)
                            }

                            Group {
                                Text("7. Children’s Privacy")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Craftify is rated 4+ and suitable for young children. We do not collect any personally identifiable information, in compliance with the Children’s Online Privacy Protection Act (COPPA, 16 CFR Part 312) in the U.S., the General Data Protection Regulation (GDPR, Regulation (EU) 2016/679) in the EU, and other applicable laws worldwide. Under GDPR Article 8, processing personal data of children under 16 (or lower, depending on the EU country) requires parental consent if based on consent. Craftify does not collect personal data as defined by GDPR, and our data processing is based on legitimate interests for app functionality, not consent, so parental consent is not required.")
                                    .font(.body)

                                Text("Parents or guardians can manage a child’s data by:")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• Using the \"Clear All Data\" button in this Support & Privacy section to remove all data from local storage, iCloud, and CloudKit.")
                                    Text("• Contacting us at hello@davevancauwenberghe.be for guidance on deleting data using the app’s features (we cannot access iCloud or CloudKit data directly).")
                                }
                                .font(.body)
                            }

                            Group {
                                Text("8. Changes to This Privacy Policy")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("We may update this policy to reflect changes in Craftify or legal requirements. Updates will be reflected in the app with the \"Last Updated\" date. Please review it periodically.")
                                    .font(.body)
                            }

                            Group {
                                Text("9. Contact Us")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .accessibilityAddTraits(.isHeader)

                                Text("For questions or privacy concerns, contact us at:")
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• **Email**: hello@davevancauwenberghe.be")
                                    Text("• **Website**: davevancauwenberghe.be")
                                }
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
                    .accessibilityLabel("Privacy Policy for Craftify, last updated 19 May 2025. Craftify for Minecraft is developed by Dave Van Cauwenberghe, an individual developer. This Privacy Policy explains how Craftify handles your data, ensuring transparency and compliance with applicable laws and App Store guidelines. We are committed to protecting your privacy. Craftify does not collect any personal information. Section 1: Data We Collect. Craftify collects Favorite Recipes and Recent Searches (stored in iCloud) and anonymous Recipe Reports via CloudKit, with local storage for My Reports. We do not collect personally identifiable information. Section 2: How We Use Your Data. We use this data to enable Favorites and Recent Searches, sync via iCloud, store recipe reports, and manage My Reports. Section 3: Data Storage and Security. Favorites and Recent Searches are stored in your iCloud account, protected by Apple’s encryption. Recipe reports are stored anonymously in CloudKit and locally on your device. Section 4: Data Sharing. We do not share your data with third parties. Section 5: Usage Data. We collect only anonymized metadata via CloudKit. Section 6: Your Control Over Your Data. You can manage Favorites, Recent Searches, clear all data, clear cache, and manage recipe reports in My Reports. Section 7: Children’s Privacy. We comply with COPPA and GDPR; no personal data is collected. Section 8: Changes to This Privacy Policy. Updates will be reflected in the app. Section 9: Contact us at hello@davevancauwenberghe.be or davevancauwenberghe.be.")
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
                            dataManager.errorMessage = "Failed to clear all data. Please try again."
                        }
                    }
                },
                secondaryButton: .cancel()
            )
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
