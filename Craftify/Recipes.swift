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
    let alternateIngredients: [String]?
    let output: Int
    let category: String
    let imageremark: String?
    let remarks: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case image
        case ingredients
        case alternateIngredients
        case output
        case category
        case imageremark
        case remarks
    }
}
