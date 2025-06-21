import Foundation
import CoreData

extension User {
    var receiptsArray: [Receipt] {
        let set = receipts as? Set<Receipt> ?? []
        return Array(set).sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    var fullName: String {
        return "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
    }
    
    var initials: String {
        let first = firstName?.first?.uppercased() ?? ""
        let last = lastName?.first?.uppercased() ?? ""
        return "\(first)\(last)"
    }
    
    static var preview: User {
        let context = PersistenceController.preview.container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = "john.doe@example.com"
        user.firstName = "John"
        user.lastName = "Doe"
        user.createdAt = Date()
        user.lastLoginAt = Date()
        user.isActive = true
        return user
    }
} 