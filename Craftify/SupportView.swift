//
//  SupportView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showClearDataAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // ─── Support ────────────────────────────────────
                Section("Support") {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let supportEmail = "hello@davevancauwenberghe.be"
                        if let url = URL(string: "mailto:\(supportEmail)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                }

                // ─── Data Management ────────────────────────────
                Section("Data Management") {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showClearDataAlert = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                    .listRowInsets(.init(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))

                    Text("Permanently deletes favorites, recent searches (iCloud), recipe reports (CloudKit), and the local recipe cache.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dataManager.clearCache { success in
                            if !success {
                                errorMessage = dataManager.errorMessage
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                    .listRowInsets(.init(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))

                    Text("Deletes only the local recipe cache; your iCloud data (favorites & searches) remains intact.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                }

                // ─── Privacy ─────────────────────────────────────
                Section("Privacy") {
                    Link(destination: URL(string: "https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/privacy-policy/")!) {
                        Label("View Privacy Policy Online", systemImage: "safari.fill")
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Policy")
                            .font(.title2)
                            .bold()
                        Text("Last updated: 20 May 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Group {
                                    Text("Craftify for Minecraft (\"Craftify\") is developed by Dave Van Cauwenberghe. We do not collect any personal information.")
                                }

                                Group {
                                    Text("1. Data We Collect")
                                        .font(.headline)
                                        .bold()
                                    Text("• Favorites: Recipe IDs when you mark a recipe as a favorite, stored in iCloud.")
                                    Text("• Recent Searches: Recipe names you search for, stored in iCloud.")
                                    Text("• Recipe Reports (Optional): Name, category & description stored privately in CloudKit.")
                                    Text("• Local Recipe Cache: Recipes cached on your device for offline use.")
                                }

                                Group {
                                    Text("2. How We Use Your Data")
                                        .font(.headline)
                                        .bold()
                                    Text("We only use your data to power core features—syncing favorites, searches, and reports across devices.")
                                }

                                Group {
                                    Text("3. Data Storage & Security")
                                        .font(.headline)
                                        .bold()
                                    Text("All data lives in your iCloud/CloudKit container, encrypted and private to you.")
                                }

                                Group {
                                    Text("4. Data Sharing")
                                        .font(.headline)
                                        .bold()
                                    Text("We share nothing with third parties; everything stays within your Apple ecosystem.")
                                }

                                Group {
                                    Text("5. Network Monitoring")
                                        .font(.headline)
                                        .bold()
                                    Text("We check your network only to manage syncing; no network data is ever stored or shared.")
                                }

                                Group {
                                    Text("6. Your Control")
                                        .font(.headline)
                                        .bold()
                                    Text("You can clear all data or just the cache at any time, and remove individual favorites, searches, or reports.")
                                }

                                Group {
                                    Text("7. Children’s Privacy")
                                        .font(.headline)
                                        .bold()
                                    Text("Rated 4+. We comply with COPPA & GDPR; no personal data of children is collected.")
                                }

                                Group {
                                    Text("8. Changes to This Policy")
                                        .font(.headline)
                                        .bold()
                                    Text("Check the “Last updated” date for the latest version.")
                                }

                                Group {
                                    Text("9. Contact Us")
                                        .font(.headline)
                                        .bold()
                                    Text("Use “Contact Support” above for any questions.")
                                }

                                Text("Thank you for using Craftify!")
                                    .font(.body)
                                    .bold()
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 400)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Support & Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)

            // Clear-all-data confirmation:
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    dataManager.clearAllData { success in
                        if !success {
                            errorMessage = dataManager.errorMessage
                            showErrorAlert = true
                        }
                    }
                }
            } message: {
                Text("This will permanently delete favorites, searches, reports, and the local cache. This cannot be undone.")
            }

            // Generic error alert:
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }
}
