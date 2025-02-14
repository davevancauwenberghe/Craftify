//
//  Recipes.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import Foundation
import SwiftUI

struct Recipe: Identifiable, Codable {
    var id: Int
    var name: String
    var image: String
    var ingredients: [String]
    var output: Int
    var category: String
}
