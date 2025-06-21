import Foundation
import CoreData

extension LineItem {
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: price)) ?? "$0.00"
    }
    
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let total = price * Double(quantity)
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
    
    static var preview: LineItem {
        let context = PersistenceController.preview.container.viewContext
        let item = LineItem(context: context)
        item.id = UUID()
        item.name = "Kirkland Paper Towels"
        item.price = 19.99
        item.quantity = 1
        item.itemCode = "123456"
        item.category = "Household"
        return item
    }
} 