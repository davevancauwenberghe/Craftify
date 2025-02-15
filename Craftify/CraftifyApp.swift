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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
