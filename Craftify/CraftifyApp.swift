//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

@main
struct CraftifyApp: App {
    @StateObject private var dataManager = DataManager()
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var onboardingOpacity: CGFloat = 1.0
    @State private var onboardingOffset: CGFloat = 0.0

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(dataManager)
                    .opacity(showOnboarding ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showOnboarding)
                
                if showOnboarding {
                    OnboardingView(
                        title: "Welcome to Craftify!",
                        message: "Fetching your Minecraft recipes…",
                        isLoading: $dataManager.isLoading,
                        errorMessage: $dataManager.errorMessage,
                        isFirstLaunch: !hasLaunchedBefore,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                onboardingOpacity = 0.0
                                onboardingOffset = -UIScreen.main.bounds.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                hasLaunchedBefore = true
                                showOnboarding = false
                                onboardingOpacity = 1.0
                                onboardingOffset = 0.0
                            }
                        },
                        onRetry: {
                            dataManager.fetchRecipes(isManual: false)
                        },
                        horizontalSizeClass: UIDevice.current.userInterfaceIdiom == .pad ? .regular : .compact
                    )
                    .environmentObject(dataManager)
                    .ignoresSafeArea()
                    .opacity(onboardingOpacity)
                    .offset(y: onboardingOffset)
                    .zIndex(1)
                }
            }
            .onAppear {
                // Fetch recipes on every app launch
                dataManager.fetchRecipes(isManual: false)
                if !hasLaunchedBefore {
                    showOnboarding = true
                }
                print("CraftifyApp: DataManager initialized, isLoading: \(dataManager.isLoading)")
            }
        }
    }
}
