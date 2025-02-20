//
//  BulkUploadDebug.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 20/02/2025.
//

#if DEBUG
import Foundation
import CloudKit

/// Reads all JSON files from the "BulkRecipes" folder in your app bundle,
/// converts them into CKRecord objects, and uploads them in bulk to CloudKit.
func bulkUploadDebug() {
    let fileManager = FileManager.default
    // Update the folder name/path as needed.
    guard let folderURL = Bundle.main.url(forResource: "BulkRecipes", withExtension: nil) else {
        print("BulkRecipes folder not found in bundle.")
        return
    }
    
    guard let fileURLs = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
        print("Could not read directory contents at \(folderURL.path)")
        return
    }
    
    // Filter for JSON files.
    let jsonFiles = fileURLs.filter { $0.pathExtension.lowercased() == "json" }
    var records: [CKRecord] = []
    let decoder = JSONDecoder()
    
    // Define a simple model matching your Minecraft JSON structure.
    struct MinecraftRecipe: Codable {
        let type: String
        let category: String
        let group: String?
        let key: [String: String]?
        let pattern: [String]
        let result: ResultItem
        
        struct ResultItem: Codable {
            let count: Int
            let id: String
        }
    }
    
    // Helper function to convert a pattern (array of strings) to a 9-element ingredients array.
    func transformPatternToIngredients(_ pattern: [String]) -> [String] {
        var ingredients = pattern
        while ingredients.count < 9 {
            ingredients.append("")
        }
        return ingredients
    }
    
    // Helper function to convert a MinecraftRecipe into a CKRecord.
    func transformToCKRecord(from recipe: MinecraftRecipe) -> CKRecord {
        // Use the recipe's result.id as the recordName.
        let recordID = CKRecord.ID(recordName: recipe.result.id)
        let record = CKRecord(recordType: "Recipe", recordID: recordID)
        
        record["name"] = recipe.result.id as CKRecordValue?
        record["category"] = recipe.category as CKRecordValue?
        
        // Flatten the pattern into a 9-element ingredients array.
        let ingredients = transformPatternToIngredients(recipe.pattern)
        record["ingredients"] = ingredients as CKRecordValue?
        
        record["output"] = recipe.result.count as CKRecordValue?
        
        // Set optional fields (image, imageremark, remarks) to empty strings by default.
        record["image"] = "" as CKRecordValue?
        record["imageremark"] = "" as CKRecordValue?
        record["remarks"] = "" as CKRecordValue?
        
        return record
    }
    
    // Process each JSON file.
    for jsonURL in jsonFiles {
        do {
            let data = try Data(contentsOf: jsonURL)
            let minecraftRecipe = try decoder.decode(MinecraftRecipe.self, from: data)
            let record = transformToCKRecord(from: minecraftRecipe)
            records.append(record)
            print("Processed \(jsonURL.lastPathComponent)")
        } catch {
            print("Error processing \(jsonURL.lastPathComponent): \(error)")
        }
    }
    
    let container = CKContainer(identifier: "iCloud.craftifydb")
    let publicDatabase = container.publicCloudDatabase
    let modifyOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
    
    modifyOperation.modifyRecordsResultBlock = { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("Successfully uploaded records.")
            case .failure(let error):
                print("Error uploading records: \(error.localizedDescription)")
            }
            // Stop the run loop to finish execution.
            CFRunLoopStop(CFRunLoopGetMain())
        }
    }
    
    publicDatabase.add(modifyOperation)
    
    // Keep the run loop active until the operation completes.
    CFRunLoopRun()
}
#endif
