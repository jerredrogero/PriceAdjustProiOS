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
        setupErrorHandling()
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
    
    private func setupErrorHandling() {
        NotificationCenter.default.publisher(for: .coreDataSaveError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?["error"] as? Error {
                    self?.errorMessage = "Failed to save data: \(error.localizedDescription). Please try again."
                }
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
        
        // Send receipt processing completion notification
        if let receiptNumber = receiptData.receiptNumber {
            // NotificationManager.shared.sendReceiptProcessingComplete(
            //     receiptNumber: receiptNumber,
            //     itemCount: receiptData.lineItems.count
            // )
        }
    }
    
    func updateReceipt(_ receipt: Receipt) {
        receipt.updatedAt = Date()
        saveContext()
    }
    
    func updateReceiptWithAPI(_ receipt: Receipt, completion: @escaping (Result<Void, Error>) -> Void) {
        AppLogger.user("Update receipt with API")
        
        guard let transactionNumber = receipt.receiptNumber else {
            AppLogger.logError(NSError(domain: "ReceiptStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Receipt number is required for API updates"]), context: "Receipt update")
            completion(.failure(NSError(domain: "ReceiptStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Receipt number is required for API updates"])))
            return
        }
        
        AppLogger.logDataOperation("Receipt update started for: \(transactionNumber)", success: true)
        
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
        

        
        // Log the request being sent (without sensitive data)
        AppLogger.logDataOperation("Sending receipt update request", success: true)
        AppLogger.logDataCount(updateRequest.items?.count ?? 0, type: "line items")
        
        APIService.shared.updateReceipt(transactionNumber: transactionNumber, updateData: updateRequest)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] apiCompletion in
                    self?.isLoading = false
                    if case .failure(let error) = apiCompletion {
                        AppLogger.logError(error, context: "Receipt API update")
                        self?.errorMessage = "Failed to update receipt on server: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                },
                receiveValue: { [weak self] updatedReceipt in
                    AppLogger.logDataOperation("Receipt API update success", success: true)
                    AppLogger.logDataCount(updatedReceipt.items.count, type: "items returned")
                    
                    // Check if server actually applied our changes
                    let sentSubtotal = updateRequest.subtotal ?? "0.00"
                    let serverSubtotal = updatedReceipt.subtotal
                    
                    // Allow for small floating point differences
                    let sentValue = Double(sentSubtotal) ?? 0.0
                    let serverValue = Double(serverSubtotal) ?? 0.0
                    let difference = abs(sentValue - serverValue)
                    
                    if difference > 0.01 {
                        AppLogger.logWarning("Server ignored local updates, keeping local changes", context: "Receipt sync")
                        
                        // Just save local changes without overwriting with server data
                        self?.saveContext()
                        self?.loadReceipts()
                        completion(.success(()))
                    } else {
                        // Server properly applied changes, update from server response
                        AppLogger.logDataOperation("Server accepted local changes", success: true)
                        self?.updateReceiptFromServerData(receipt, serverReceipt: updatedReceipt)
                        self?.saveContext()
                        self?.loadReceipts()
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
        guard let persistenceController = persistenceController else { 
            errorMessage = "Data storage is not available"
            return 
        }
        
        // Use the enhanced save method from PersistenceController
        persistenceController.save()
    }
    
    // MARK: - Search and Filter
    
    private func filterReceipts(with searchText: String) {
        guard let context = viewContext else { return }
        
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        if !searchText.isEmpty {
            // Search in store name, receipt number, notes, and line item names
            let predicate = NSPredicate(format: "storeName CONTAINS[cd] %@ OR receiptNumber CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR storeLocation CONTAINS[cd] %@ OR ANY lineItems.name CONTAINS[cd] %@", 
                                      searchText, searchText, searchText, searchText, searchText)
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
                        AppLogger.logError(error, context: "Receipt sync")
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
                AppLogger.logError(error, context: "Receipt sync individual item")
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
        AppLogger.logDataOperation("Updating local receipt from server data", success: true)
        
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
        
        // Update line items
        // First, remove all existing line items
        let existingItemsCount = receipt.lineItemsArray.count
        AppLogger.logDataOperation("Removing \(existingItemsCount) existing line items", success: true)
        
        if let existingItems = receipt.lineItems as? Set<LineItem> {
            for item in existingItems {
                viewContext?.delete(item)
            }
        }
        
        // Then create new line items
        AppLogger.logDataCount(serverReceipt.items.count, type: "new line items from server")
        for itemData in serverReceipt.items {
            let lineItem = LineItem(context: viewContext!)
            lineItem.id = UUID()
            lineItem.name = itemData.description
            lineItem.price = Double(itemData.price) ?? 0.0
            lineItem.quantity = Int32(itemData.quantity)
            lineItem.itemCode = itemData.itemCode
            lineItem.category = nil // API doesn't provide category
            lineItem.receipt = receipt
            
        }
        
        AppLogger.logDataOperation("Local receipt update complete", success: true)
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
                    
                    // Send notification for successful upload processing
                    // NotificationManager.shared.sendReceiptProcessingComplete(
                    //     receiptNumber: serverReceipt.transactionNumber,
                    //     itemCount: serverReceipt.items.count
                    // )
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
    
    func getReceiptCount(for period: DateInterval? = nil) -> Int {
        return receipts
            .filter { receipt in
                if let period = period {
                    return period.contains(receipt.date ?? Date())
                }
                return true
            }
            .count
    }
    
    func getAverageReceiptAmount(for period: DateInterval? = nil) -> Double {
        let filteredReceipts = receipts.filter { receipt in
            if let period = period {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        guard !filteredReceipts.isEmpty else { return 0.0 }
        
        let total = filteredReceipts.reduce(0) { $0 + $1.total }
        return total / Double(filteredReceipts.count)
    }
    
    func getSpendingByMonth(for period: DateInterval? = nil) -> [String: Double] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        var spendingByMonth: [String: Double] = [:]
        
        let filteredReceipts = receipts.filter { receipt in
            if let period = period {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        for receipt in filteredReceipts {
            let monthKey = dateFormatter.string(from: receipt.date ?? Date())
            spendingByMonth[monthKey, default: 0] += receipt.total
        }
        
        return spendingByMonth
    }
    
    func getTopCategories(for period: DateInterval? = nil) -> [String: Double] {
        var categorySpending: [String: Double] = [:]
        
        let filteredReceipts = receipts.filter { receipt in
            if let period = period {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        for receipt in filteredReceipts {
            for lineItem in receipt.lineItemsArray {
                let category = lineItem.category ?? "Other"
                categorySpending[category, default: 0] += lineItem.price * Double(lineItem.quantity)
            }
        }
        
        return categorySpending
    }
    
    // MARK: - Date Helpers
    
    func dateInterval(for timeFrame: String) -> DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFrame.lowercased() {
        case "week":
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)
            
        case "month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)
            
        case "year":
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return DateInterval(start: startOfYear, end: now)
            
        case "all", "all time":
            return nil // Return nil for all time (no filtering)
            
        default:
            return nil
        }
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
            AppLogger.logDataOperation("Cleared all local receipts", success: true)
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