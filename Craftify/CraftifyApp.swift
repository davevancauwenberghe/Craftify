//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import UIKit
import Combine

@main
struct CraftifyApp: App {
    init() {
        let tabBarAppearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
                // Liquid Glass: Use transparent background with vibrancy
                tabBarAppearance.configureWithTransparentBackground()
                let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                tabBarAppearance.backgroundEffect = blurEffect
                tabBarAppearance.backgroundColor = .clear
        } else {
            tabBarAppearance.configureWithDefaultBackground()
        }
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    @StateObject private var dataManager = DataManager()
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @State private var showOnboarding: Bool = false
    @State private var dismissOnboardingAfterLoading = true

    var body: some Scene {
        WindowGroup {
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
                            dataManager.fetchRecipes(isManual: false)
                        },
                        horizontalSizeClass: UIDevice.current.userInterfaceIdiom == .pad ? .regular : .compact
                    )
                    .environmentObject(dataManager)
                    .background {
                        if #available(iOS 26.0, *) {
                            // Liquid Glass: Vibrant, translucent background
                            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                                .ignoresSafeArea()
                        }
                    }
                    .zIndex(1)
                }
            }
            .tint(Color.userAccentColor)
            .dynamicTypeSize(.xSmall ... .accessibility5)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Craftify App")
            .onAppear {
                dataManager.fetchRecipes(isManual: false)
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

// Helper view for iOS 26 vibrancy effect
@available(iOS 26.0, *)
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: effect)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: effect as! UIBlurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        view.contentView.addSubview(vibrancyView)
        vibrancyView.frame = view.bounds
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}
