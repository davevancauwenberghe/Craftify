//
//  Recipes.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation

struct Recipe: Codable, Identifiable, Equatable {
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

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.image == rhs.image &&
               lhs.ingredients == rhs.ingredients &&
               lhs.alternateIngredients == rhs.alternateIngredients &&
               lhs.alternateIngredients1 == rhs.alternateIngredients1 &&
               lhs.alternateIngredients2 == rhs.alternateIngredients2 &&
               lhs.alternateIngredients3 == rhs.alternateIngredients3 &&
               lhs.output == rhs.output &&
               lhs.alternateOutput == rhs.alternateOutput &&
               lhs.alternateOutput1 == rhs.alternateOutput1 &&
               lhs.alternateOutput2 == rhs.alternateOutput2 &&
               lhs.alternateOutput3 == rhs.alternateOutput3 &&
               lhs.category == rhs.category &&
               lhs.imageremark == rhs.imageremark &&
               lhs.remarks == rhs.remarks
    }
}
