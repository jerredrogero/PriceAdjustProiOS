import CoreData
import Foundation


// MARK: - Notification Names
extension Notification.Name {
    static let coreDataSaveError = Notification.Name("coreDataSaveError")
}

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        // No sample data - use real data from server instead
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PriceAdjustPro")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        let persistentContainer = container // Capture container to avoid self capture
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error for debugging  
                print("❌ Core Data failed to load persistent store: \(error.localizedDescription)")
                
                // Attempt to delete and recreate the store if it's corrupted
                if let storeURL = storeDescription.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        print("🔄 Deleted corrupted store, attempting to recreate")
                        
                        // Try to load again after deletion
                        persistentContainer.loadPersistentStores { _, recreateError in
                            if let recreateError = recreateError {
                                print("❌ Failed to recreate store: \(recreateError.localizedDescription)")
                                // At this point, we could show a user-facing error or reset to defaults
                            } else {
                                print("✅ Successfully recreated Core Data store")
                            }
                        }
                    } catch {
                        print("❌ Failed to delete corrupted store: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Log the error for debugging
                let nsError = error as NSError
                print("❌ Core Data save failed: \(nsError.localizedDescription)")
                
                // Attempt to rollback and retry
                context.rollback()
                
                // Try saving again after rollback
                if context.hasChanges {
                    do {
                        try context.save()
                        print("✅ Core Data save succeeded after rollback")
                    } catch {
                        print("❌ Core Data save failed even after rollback: \(error.localizedDescription)")
                        // Post notification so the UI can handle the error
                        NotificationCenter.default.post(
                            name: .coreDataSaveError,
                            object: nil,
                            userInfo: ["error": error]
                        )
                    }
                }
            }
        }
    }
} 