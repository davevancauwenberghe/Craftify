//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Combine
import SwiftUI

@main
struct CraftifyApp: App {
    @StateObject private var dataManager = DataManager.forAppLaunch()
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @State private var showOnboarding: Bool = false
    @State private var dismissOnboardingAfterLoading = true

    var body: some Scene {
        WindowGroup {
            let accent = Color.userAccentColor(for: accentColorPreference)

            ContentView()
                .environmentObject(dataManager)
                .sheet(isPresented: $showOnboarding) {
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
                    .interactiveDismissDisabled(!hasLaunchedBefore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(hasLaunchedBefore ? .visible : .hidden)
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

extension DataManager {
    static func forAppLaunch() -> DataManager {
        #if DEBUG
            if ProcessInfo.processInfo.isCraftifyTestProcess {
                return CraftifyTestData.makeDataManager()
            }
        #endif
        return DataManager()
    }
}

extension ProcessInfo {
    var isCraftifyTestProcess: Bool {
        #if DEBUG
            arguments.contains("-ui-testing") || environment["XCTestConfigurationFilePath"] != nil
        #else
            false
        #endif
    }
}

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
}
