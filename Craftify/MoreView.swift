//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    // Persist the appearance selection using AppStorage.
    // Allowed values: "system", "light", "dark"
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance settings section at the top.
                Section(header: Text("Appearance")) {
                    Picker("Appearance", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // "Need help?" section with the missing recipe button.
                Section(header: Text("Need help?")) {
                    Button(action: {
                        if let url = URL(string: "mailto:hello@davevancauwenberghe.be") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(Color(hex: "00AA00"))
                            Text("Missing recipe")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    // Future help options can be added in this section.
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
        }
        // Apply the remembered appearance.
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }
}
