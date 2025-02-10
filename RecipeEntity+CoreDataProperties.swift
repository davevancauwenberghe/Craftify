//
//  RecipeEntity+CoreDataProperties.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 11/02/2025.
//
//

import Foundation
import CoreData


extension RecipeEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecipeEntity> {
        return NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
    }

    @NSManaged public var category: String?
    @NSManaged public var id: Int64
    @NSManaged public var image: String?
    @NSManaged public var ingredients: NSObject?
    @NSManaged public var name: String?
    @NSManaged public var output: Int64

}

extension RecipeEntity : Identifiable {

}
