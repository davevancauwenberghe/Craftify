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
    let alternateIngredients1: [String]?
    let alternateIngredients2: [String]?
    let alternateIngredients3: [String]?

    let output: Int
    let alternateOutput: Int?
    let alternateOutput1: Int?
    let alternateOutput2: Int?
    let alternateOutput3: Int?

    let category: String
    let imageremark: String?
    let remarks: String?

    enum CodingKeys: String, CodingKey {
        case id, name, image, ingredients
        case alternateIngredients,
             alternateIngredients1,
             alternateIngredients2,
             alternateIngredients3
        case output,
             alternateOutput,
             alternateOutput1,
             alternateOutput2,
             alternateOutput3
        case category, imageremark, remarks
    }
}

