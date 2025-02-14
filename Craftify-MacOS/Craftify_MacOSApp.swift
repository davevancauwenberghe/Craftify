//
//  Craftify_MacOSApp.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import SwiftUI

#if os(macOS)
@main
struct CraftifyMacOSApp: App {
    @StateObject var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .frame(minWidth: 800, minHeight: 600) // macOS minimum window size
        }
    }
}
#else
@main
struct CraftifyApp: App {
    @StateObject var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
#endif

