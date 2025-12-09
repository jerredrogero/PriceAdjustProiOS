import Foundation
import CoreData

extension Receipt {
    var lineItemsArray: [LineItem] {
        let set = lineItems as? Set<LineItem> ?? []
        // Sort by orderIndex to preserve the original receipt order
        return Array(set).sorted { $0.orderIndex < $1.orderIndex }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date ?? Date())
    }
    
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
    
    var formattedSubtotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: subtotal)) ?? "$0.00"
    }
    
    var formattedTax: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: tax)) ?? "$0.00"
    }
    
    static var preview: Receipt {
        let context = PersistenceController.preview.container.viewContext
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.storeName = "Costco Wholesale"
        receipt.storeLocation = "Mountain View, CA"
        receipt.date = Date()
        receipt.receiptNumber = "123456789"
        receipt.subtotal = 99.99
        receipt.tax = 8.25
        receipt.total = 108.24
        receipt.isProcessed = true
        receipt.processingStatus = "completed"
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        // Add some sample line items
        let item1 = LineItem(context: context)
        item1.id = UUID()
        item1.name = "Kirkland Paper Towels"
        item1.price = 19.99
        item1.quantity = 1
        item1.itemCode = "123456"
        item1.category = "Household"
        item1.receipt = receipt
        
        let item2 = LineItem(context: context)
        item2.id = UUID()
        item2.name = "Rotisserie Chicken"
        item2.price = 4.99
        item2.quantity = 1
        item2.itemCode = "789012"
        item2.category = "Food"
        item2.receipt = receipt
        
        return receipt
    }
} 