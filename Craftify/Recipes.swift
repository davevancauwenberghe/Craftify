//
//  Recipes.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation

struct Recipe: Codable, Identifiable {
    let id: Int
    let name: String
    let image: String
    let ingredients: [String]
    let output: Int
    let category: String // New field for categorization
}
