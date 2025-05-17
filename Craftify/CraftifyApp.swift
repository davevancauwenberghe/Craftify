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
                // Always render ContentView, but it will be obscured by OnboardingView when active
                ContentView()
                    .environmentObject(dataManager)
                    .opacity(showOnboarding ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showOnboarding)
                
                // Present OnboardingView on top with animation
                if showOnboarding {
                    OnboardingView(
                        title: "Welcome to Craftify!",
                        message: "Fetching your Minecraft recipes…",
                        isLoading: $dataManager.isLoading,
                        errorMessage: $dataManager.errorMessage,
                        isFirstLaunch: !hasLaunchedBefore,
                        onDismiss: {
                            // Animate OnboardingView out before setting showOnboarding to false
                            withAnimation(.easeInOut(duration: 0.5)) {
                                onboardingOpacity = 0.0
                                onboardingOffset = -UIScreen.main.bounds.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                hasLaunchedBefore = true
                                showOnboarding = false
                                // Reset animation properties for future onboarding presentations
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
                if !hasLaunchedBefore {
                    showOnboarding = true
                    dataManager.fetchRecipes(isManual: false)
                }
                print("CraftifyApp: DataManager initialized, isLoading: \(dataManager.isLoading)")
            }
        }
    }
}
