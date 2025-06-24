//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import UserNotifications
import CloudKit

@main
struct CraftifyApp: App {
    @StateObject private var dataManager = DataManager()
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var onboardingOpacity: CGFloat = 1.0
    @State private var onboardingOffset: CGFloat = 0.0
    @State private var navigateToMyReports: Bool = false

    init() {
        #if os(iOS)
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(navigateToMyReports: $navigateToMyReports)
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
                
                #if os(iOS)
                // Register for push notifications
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                    if let error = error {
                        print("Notification authorization error: \(error.localizedDescription)")
                    }
                }
                #endif
            }
            .onChange(of: navigateToMyReports) { _, newValue in
                if !newValue {
                    // Reset navigation state after handling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigateToMyReports = false
                    }
                }
            }
        }
    }
}

// Singleton for notification delegate to avoid strong reference cycles
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {}

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
           ckNotification.recordID != nil {
            // Trigger navigation to My Reports
            NotificationCenter.default.post(name: .navigateToMyReports, object: nil)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let navigateToMyReports = Notification.Name("NavigateToMyReports")
}
