//
//  CraftifyApp.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

@main
struct CraftifyApp: App {
    @StateObject var dataManager = DataManager()  // Initialize DataManager as a StateObject

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)  // Pass DataManager as EnvironmentObject
        }
    }
}
