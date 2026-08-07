//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine

@main
struct CraftifyApp: App {
    @StateObject private var dataManager = DataManager()
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @State private var showOnboarding: Bool = false
    @State private var dismissOnboardingAfterLoading = true

    var body: some Scene {
        WindowGroup {
            let accent = Color.userAccentColor(for: accentColorPreference)

            ZStack {
                ContentView()
                    .environmentObject(dataManager)

                if showOnboarding {
                    OnboardingView(
                        title: "Welcome to Craftify!",
                        message: "Fetching your Minecraft recipes…",
                        isLoading: $dataManager.isLoading,
                        errorMessage: $dataManager.errorMessage,
                        isFirstLaunch: !hasLaunchedBefore,
                        dismissAfterLoading: dismissOnboardingAfterLoading,
                        onDismiss: {
                            hasLaunchedBefore = true
                            showOnboarding = false
                        },
                        onRetry: {
                            dataManager.fetchRecipes(
                                isManual: false,
                                waitForImages: !hasLaunchedBefore
                            )
                        }
                    )
                    .environmentObject(dataManager)
                    .zIndex(1)
                }
            }
            .tint(accent)
            .environment(\.craftifyAccentColor, accent)
            .dynamicTypeSize(.xSmall ... .accessibility5)
            .onAppear {
                dataManager.fetchRecipes(
                    isManual: false,
                    waitForImages: !hasLaunchedBefore
                )
                if !hasLaunchedBefore {
                    dismissOnboardingAfterLoading = true
                    showOnboarding = true
                }
                print("CraftifyApp: DataManager initialized, isLoading: \(dataManager.isLoading)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
                dismissOnboardingAfterLoading = false
                showOnboarding = true
            }
        }
    }
}

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
}
