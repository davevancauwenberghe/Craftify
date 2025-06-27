//
//  Recipes.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import Foundation
import CloudKit

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

struct RecipeReport: Identifiable, Codable {
    let id: String
    let recordID: String?
    let localID: String
    let reportType: String
    let recipeName: String
    let category: String
    let recipeID: Int?
    let description: String
    let timestamp: Date
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, recordID, localID, reportType, recipeName, category, recipeID, description, timestamp, status
    }

    init(id: String, recordID: String?, localID: String, reportType: String, recipeName: String, category: String, recipeID: Int?, description: String, timestamp: Date, status: String) {
        self.id = id
        self.recordID = recordID
        self.localID = localID
        self.reportType = reportType
        self.recipeName = recipeName
        self.category = category
        self.recipeID = recipeID
        self.description = description
        self.timestamp = timestamp
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.recordID = try container.decodeIfPresent(String.self, forKey: .recordID)
        self.localID = try container.decode(String.self, forKey: .localID)
        self.reportType = try container.decode(String.self, forKey: .reportType)
        self.recipeName = try container.decode(String.self, forKey: .recipeName)
        self.category = try container.decode(String.self, forKey: .category)
        self.recipeID = try container.decodeIfPresent(Int.self, forKey: .recipeID)
        self.description = try container.decode(String.self, forKey: .description)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.status = try container.decode(String.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(recordID, forKey: .recordID)
        try container.encode(localID, forKey: .localID)
        try container.encode(reportType, forKey: .reportType)
        try container.encode(recipeName, forKey: .recipeName)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(recipeID, forKey: .recipeID)
        try container.encode(description, forKey: .description)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(status, forKey: .status)
    }

    init?(from record: CKRecord) {
        guard
            let localID = record["localID"] as? String,
            let reportType = record["reportType"] as? String,
            let recipeName = record["recipeName"] as? String,
            let category = record["category"] as? String,
            let description = record["description"] as? String,
            let timestamp = record["timestamp"] as? Date,
            let status = record["status"] as? String
        else {
            return nil
        }

        self.id = localID
        self.recordID = record.recordID.recordName
        self.localID = localID
        self.reportType = reportType
        self.recipeName = recipeName
        self.category = category
        self.recipeID = record["recipeID"] as? Int
        self.description = description
        self.timestamp = timestamp
        self.status = status
    }
}

struct ConsoleCommand: Identifiable, Codable, Equatable {
    /// CloudKit recordName
    let id: String

    /// fields
    let name: String
    let description: String
    let worksInBedrock: Bool
    let worksInJava: Bool

    /// optional OP levels
    let opLevelBedrock: Int64?
    let opLevelJava: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, description, worksInBedrock, worksInJava, opLevelBedrock, opLevelJava
    }

    /// Designated initializer
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        worksInBedrock: Bool,
        worksInJava: Bool,
        opLevelBedrock: Int64? = nil,
        opLevelJava: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.worksInBedrock = worksInBedrock
        self.worksInJava = worksInJava
        self.opLevelBedrock = opLevelBedrock
        self.opLevelJava = opLevelJava
    }

    /// Initialize from a CKRecord
    init?(from record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let desc = record["description"] as? String
        else {
            return nil
        }

        self.id = record.recordID.recordName
        self.name = name
        self.description = desc

        // Booleans stored as INT64
        let bedrockValue = record["worksInBedrock"] as? Int64 ?? 0
        self.worksInBedrock = (bedrockValue == 1)

        let javaValue = record["worksInJava"] as? Int64 ?? 0
        self.worksInJava = (javaValue == 1)

        // Optional OP levels
        self.opLevelBedrock = record["opLevelBedrock"] as? Int64
        self.opLevelJava = record["opLevelJava"] as? Int64
    }
}
