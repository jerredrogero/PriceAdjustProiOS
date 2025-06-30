import Foundation
import CoreData
import Combine
import SwiftUI

class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedReceipt: Receipt?
    
    private var persistenceController: PersistenceController?
    private var cancellables = Set<AnyCancellable>()
    
    private var viewContext: NSManagedObjectContext? {
        return persistenceController?.container.viewContext
    }
    
    init() {
        setupSearchSubscription()
    }
    
    func setPersistenceController(_ controller: PersistenceController) {
        self.persistenceController = controller
        loadReceipts()
    }
    
    private func setupSearchSubscription() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.filterReceipts(with: searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Data Operations
    
    func loadReceipts() {
        guard let context = viewContext else { return }
        
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        do {
            receipts = try context.fetch(request)
        } catch {
            errorMessage = "Failed to load receipts: \(error.localizedDescription)"
        }
    }

    
    func createReceipt(from receiptData: ReceiptData, pdfData: Data? = nil, imageData: Data? = nil) {
        guard let context = viewContext else { return }
        
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.storeName = receiptData.storeName
        receipt.date = receiptData.date ?? Date()
        receipt.receiptNumber = receiptData.receiptNumber
        receipt.subtotal = receiptData.subtotal
        receipt.tax = receiptData.tax
        receipt.total = receiptData.total
        receipt.pdfData = pdfData
        receipt.imageData = imageData
        receipt.isProcessed = true
        receipt.processingStatus = "completed"
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        // Create line items
        for itemData in receiptData.lineItems {
            let lineItem = LineItem(context: context)
            lineItem.id = UUID()
            lineItem.name = itemData.name
            lineItem.price = itemData.price
            lineItem.quantity = Int32(itemData.quantity)
            lineItem.itemCode = itemData.itemCode
            lineItem.category = itemData.category
            lineItem.receipt = receipt
        }
        
        saveContext()
        loadReceipts()
    }
    
    func updateReceipt(_ receipt: Receipt) {
        receipt.updatedAt = Date()
        saveContext()
    }
    
    func updateReceiptWithAPI(_ receipt: Receipt, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 updateReceiptWithAPI called!")
        
        guard let transactionNumber = receipt.receiptNumber else {
            print("❌ No transaction number found!")
            completion(.failure(NSError(domain: "ReceiptStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Receipt number is required for API updates"])))
            return
        }
        
        print("✅ Transaction number: \(transactionNumber)")
        
        isLoading = true
        errorMessage = nil
        
        // Create line item update requests
        let lineItemRequests = receipt.lineItemsArray.map { lineItem in
            UpdateLineItemRequest(
                id: nil, // Let the server handle IDs
                itemCode: lineItem.itemCode ?? "",
                description: lineItem.name ?? "",
                price: String(format: "%.2f", lineItem.price),
                quantity: Int(lineItem.quantity),
                totalPrice: String(format: "%.2f", lineItem.price * Double(lineItem.quantity))
            )
        }
        
        // Create update request
        let dateFormatter = ISO8601DateFormatter()
        let updateRequest = UpdateReceiptRequest(
            acceptManualEdits: true, // Always preserve manual edits from the iOS app
            storeLocation: receipt.storeLocation,
            transactionDate: receipt.date != nil ? dateFormatter.string(from: receipt.date!) : nil,
            subtotal: String(format: "%.2f", receipt.subtotal),
            tax: String(format: "%.2f", receipt.tax),
            total: String(format: "%.2f", receipt.total),
            notes: receipt.notes,
            items: lineItemRequests
        )
        

        
        // Debug: Log the request being sent
        print("📤 SENDING UPDATE REQUEST:")
        print("Transaction Number: \(transactionNumber)")
        print("Accept Manual Edits: \(updateRequest.acceptManualEdits)")
        print("Store Location: \(updateRequest.storeLocation ?? "nil")")
        print("Subtotal: \(updateRequest.subtotal ?? "nil")")
        print("Tax: \(updateRequest.tax ?? "nil")")
        print("Total: \(updateRequest.total ?? "nil")")
        print("Items count: \(updateRequest.items?.count ?? 0)")
        
        APIService.shared.updateReceipt(transactionNumber: transactionNumber, updateData: updateRequest)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] apiCompletion in
                    self?.isLoading = false
                    if case .failure(let error) = apiCompletion {
                        print("❌ API UPDATE FAILED: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to update receipt on server: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                },
                receiveValue: { [weak self] updatedReceipt in
                    print("✅ API UPDATE SUCCESS - Server Response:")
                    print("Transaction Number: \(updatedReceipt.transactionNumber)")
                    print("Store Location: \(updatedReceipt.storeLocation)")
                    print("Subtotal: \(updatedReceipt.subtotal)")
                    print("Tax: \(updatedReceipt.tax)")
                    print("Total: \(updatedReceipt.total)")
                    print("Items count: \(updatedReceipt.items.count)")
                    
                    // Check if server actually applied our changes
                    let sentSubtotal = updateRequest.subtotal ?? "0.00"
                    let serverSubtotal = updatedReceipt.subtotal
                    
                    // Allow for small floating point differences
                    let sentValue = Double(sentSubtotal) ?? 0.0
                    let serverValue = Double(serverSubtotal) ?? 0.0
                    let difference = abs(sentValue - serverValue)
                    
                    if difference > 0.01 {
                        print("⚠️ WARNING: Server ignored our updates!")
                        print("Sent subtotal: \(sentSubtotal) (\(sentValue)), Server returned: \(serverSubtotal) (\(serverValue))")
                        print("Difference: \(difference)")
                        print("Keeping local changes instead of server response")
                        
                        // Just save local changes without overwriting with server data
                        self?.saveContext()
                        self?.loadReceipts()
                        completion(.success(()))
                    } else {
                        // Server properly applied changes, update from server response
                        print("✅ Server accepted our changes - updating from server response")
                        self?.updateReceiptFromServerData(receipt, serverReceipt: updatedReceipt)
                        self?.saveContext()
                        self?.loadReceipts()
                        print("✅ LOCAL UPDATE COMPLETE")
                        completion(.success(()))
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteReceipt(_ receipt: Receipt) {
        guard let context = viewContext else { return }
        
        context.delete(receipt)
        saveContext()
        loadReceipts()
    }
    
    func deleteReceipts(at offsets: IndexSet) {
        guard let context = viewContext else { return }
        
        for index in offsets {
            context.delete(receipts[index])
        }
        
        saveContext()
        loadReceipts()
    }
    
    private func saveContext() {
        guard let context = viewContext else { return }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                errorMessage = "Failed to save receipt: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Search and Filter
    
    private func filterReceipts(with searchText: String) {
        guard let context = viewContext else { return }
        
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        if !searchText.isEmpty {
            let predicate = NSPredicate(format: "storeName CONTAINS[cd] %@ OR receiptNumber CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", searchText, searchText, searchText)
            request.predicate = predicate
        }
        
        do {
            receipts = try context.fetch(request)
        } catch {
            errorMessage = "Failed to filter receipts: \(error.localizedDescription)"
        }
    }
    
    // MARK: - API Sync
    
    func syncWithServer() {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.getReceipts()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to sync receipts from server."
                        print("Receipt sync error: \(error)")
                        // Still load local receipts even if sync fails
                        self?.loadReceipts()
                    }
                },
                receiveValue: { [weak self] serverReceipts in
                    self?.syncServerReceipts(serverReceipts)
                }
            )
            .store(in: &cancellables)
    }
    
    private func syncServerReceipts(_ serverReceipts: [ReceiptResponse]) {
        guard let context = viewContext else { return }
        
        for serverReceipt in serverReceipts {
            // Check if receipt already exists locally using transaction number
            let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
            request.predicate = NSPredicate(format: "receiptNumber == %@", serverReceipt.transactionNumber)
            
            do {
                let existingReceipts = try context.fetch(request)
                if existingReceipts.isEmpty {
                    // Create new receipt from server data
                    createReceiptFromServerData(serverReceipt, context: context)
                } else {
                    // Update existing receipt
                    updateReceiptFromServerData(existingReceipts.first!, serverReceipt: serverReceipt)
                }
            } catch {
                print("Error syncing receipt: \(error)")
            }
        }
        
        saveContext()
        loadReceipts()
    }
    
    private func createReceiptFromServerData(_ serverReceipt: ReceiptResponse, context: NSManagedObjectContext) {
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.receiptNumber = serverReceipt.transactionNumber
        receipt.storeName = serverReceipt.storeLocation ?? "Unknown Store"
        receipt.storeLocation = serverReceipt.storeLocation ?? "Unknown Location"
        receipt.date = serverReceipt.date ?? Date()
        receipt.subtotal = Double(serverReceipt.subtotal) ?? 0.0
        receipt.tax = Double(serverReceipt.tax) ?? 0.0
        receipt.total = Double(serverReceipt.total) ?? 0.0
        receipt.isProcessed = serverReceipt.parsedSuccessfully
        receipt.processingStatus = serverReceipt.parsedSuccessfully ? "completed" : "failed"
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        // Create line items
        for itemData in serverReceipt.items {
            let lineItem = LineItem(context: context)
            lineItem.id = UUID()
            lineItem.name = itemData.description
            lineItem.price = Double(itemData.price) ?? 0.0
            lineItem.quantity = Int32(itemData.quantity)
            lineItem.itemCode = itemData.itemCode
            lineItem.category = nil // API doesn't provide category
            lineItem.receipt = receipt
        }
    }
    
    private func updateReceiptFromServerData(_ receipt: Receipt, serverReceipt: ReceiptResponse) {
        print("🔄 UPDATING LOCAL RECEIPT FROM SERVER DATA")
        print("Before update - Local receipt total: \(receipt.total)")
        print("Server response total: \(serverReceipt.total)")
        
        receipt.receiptNumber = serverReceipt.transactionNumber
        receipt.storeName = serverReceipt.storeLocation ?? receipt.storeName ?? "Unknown Store"
        receipt.storeLocation = serverReceipt.storeLocation ?? receipt.storeLocation ?? "Unknown Location"
        receipt.date = serverReceipt.date ?? Date()
        receipt.subtotal = Double(serverReceipt.subtotal) ?? 0.0
        receipt.tax = Double(serverReceipt.tax) ?? 0.0
        receipt.total = Double(serverReceipt.total) ?? 0.0
        receipt.isProcessed = serverReceipt.parsedSuccessfully
        receipt.processingStatus = serverReceipt.parsedSuccessfully ? "completed" : "failed"
        receipt.updatedAt = Date()
        
        print("After basic update - Local receipt total: \(receipt.total)")
        
        // Update line items
        // First, remove all existing line items
        let existingItemsCount = receipt.lineItemsArray.count
        print("Removing \(existingItemsCount) existing line items")
        
        if let existingItems = receipt.lineItems as? Set<LineItem> {
            for item in existingItems {
                viewContext?.delete(item)
            }
        }
        
        // Then create new line items
        print("Creating \(serverReceipt.items.count) new line items from server")
        for itemData in serverReceipt.items {
            let lineItem = LineItem(context: viewContext!)
            lineItem.id = UUID()
            lineItem.name = itemData.description
            lineItem.price = Double(itemData.price) ?? 0.0
            lineItem.quantity = Int32(itemData.quantity)
            lineItem.itemCode = itemData.itemCode
            lineItem.category = nil // API doesn't provide category
            lineItem.receipt = receipt
            
            print("Created line item: \(itemData.description) - $\(itemData.price) x \(itemData.quantity)")
        }
        
        print("🔄 LOCAL RECEIPT UPDATE COMPLETE")
    }
    
    // MARK: - Upload Receipt
    
    func uploadReceiptToServer(pdfData: Data, fileName: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.uploadReceipt(pdfData: pdfData, fileName: fileName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] serverReceipt in
                    self?.syncServerReceipts([serverReceipt])
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Analytics
    
    func getTotalSpending(for period: DateInterval? = nil) -> Double {
        return receipts
            .filter { receipt in
                if let period = period {
                    return period.contains(receipt.date ?? Date())
                }
                return true
            }
            .reduce(0) { $0 + $1.total }
    }
    
    func getSpendingByMonth() -> [String: Double] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        var spendingByMonth: [String: Double] = [:]
        
        for receipt in receipts {
            let monthKey = dateFormatter.string(from: receipt.date ?? Date())
            spendingByMonth[monthKey, default: 0] += receipt.total
        }
        
        return spendingByMonth
    }
    
    func getTopCategories() -> [String: Double] {
        var categorySpending: [String: Double] = [:]
        
        for receipt in receipts {
            for lineItem in receipt.lineItemsArray {
                let category = lineItem.category ?? "Other"
                categorySpending[category, default: 0] += lineItem.price
            }
        }
        
        return categorySpending
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Clear Data
    
    func clearAllLocalReceipts() {
        guard let context = viewContext else { return }
        
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        do {
            let receipts = try context.fetch(request)
            for receipt in receipts {
                context.delete(receipt)
            }
            saveContext()
            loadReceipts()
            print("Cleared all local receipts")
        } catch {
            errorMessage = "Failed to clear receipts: \(error.localizedDescription)"
        }
    }
}

// MARK: - Receipt Extension

extension Receipt {
    var lineItemsArray: [LineItem] {
        return (lineItems?.allObjects as? [LineItem]) ?? []
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
} 