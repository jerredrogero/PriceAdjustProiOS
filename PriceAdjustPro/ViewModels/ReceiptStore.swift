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
        if !receiptData.receiptNumber.isEmpty {
            // NotificationManager.shared.sendReceiptProcessingComplete(
            //     receiptNumber: receiptData.receiptNumber,
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
        guard let receiptNumber = receipt.receiptNumber else {
            errorMessage = "Cannot delete receipt: No receipt number found"
            AppLogger.logWarning("Attempted to delete receipt without receipt number", context: "ReceiptStore")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        AppLogger.logDataOperation("Starting receipt deletion: \(receiptNumber)", success: true)
        
        Task {
            do {
                // First delete from server
                AppLogger.logDataOperation("Attempting server deletion for receipt: \(receiptNumber)", success: true)
                try await APIService.shared.deleteReceipt(id: receiptNumber)
                AppLogger.logDataOperation("Server deletion successful for receipt: \(receiptNumber)", success: true)
                
                // Then delete locally
                await MainActor.run {
                    guard let context = viewContext else { 
                        isLoading = false
                        errorMessage = "Local storage not available"
                        AppLogger.logError(NSError(domain: "ReceiptStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local storage not available"]), context: "Delete receipt")
                        return 
                    }
                    
                    AppLogger.logDataOperation("Starting local deletion for receipt: \(receiptNumber)", success: true)
                    context.delete(receipt)
                    saveContext()
                    loadReceipts()
                    isLoading = false
                    AppLogger.logDataOperation("Receipt deletion completed successfully: \(receiptNumber)", success: true)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMsg = "Failed to delete receipt \(receiptNumber): \(error.localizedDescription)"
                    errorMessage = errorMsg
                    AppLogger.logError(error, context: "Delete receipt from server")
                    
                    // Log the specific error details for debugging
                    if let apiError = error as? APIService.APIError {
                        AppLogger.logWarning("API Error details: \(apiError)", context: "Receipt deletion")
                    }
                }
            }
        }
    }
    
    func deleteReceipts(at offsets: IndexSet) {
        guard let context = viewContext else { 
            AppLogger.logError(NSError(domain: "ReceiptStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "ViewContext not available"]), context: "Batch delete receipts")
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        let receiptsToDelete = offsets.map { receipts[$0] }
        let receiptNumbers = receiptsToDelete.compactMap { $0.receiptNumber }
        
        AppLogger.logDataOperation("Starting batch deletion of \(receiptsToDelete.count) receipts: \(receiptNumbers)", success: true)
        
        Task {
            // Collect deletion errors in a thread-safe way
            let deletionResults = await withTaskGroup(of: (String?, String).self) { group in
                var results: [(String?, String)] = []
                
                for receipt in receiptsToDelete {
                    guard let receiptNumber = receipt.receiptNumber else {
                        AppLogger.logWarning("Skipping receipt without number in batch delete", context: "ReceiptStore")
                        continue
                    }
                    
                    group.addTask {
                        do {
                            AppLogger.logDataOperation("Attempting server deletion for receipt: \(receiptNumber)", success: true)
                            try await APIService.shared.deleteReceipt(id: receiptNumber)
                            AppLogger.logDataOperation("Server deletion successful for receipt: \(receiptNumber)", success: true)
                            return (nil, receiptNumber) // Success
                        } catch {
                            let errorMsg = "Failed to delete \(receiptNumber) from server: \(error.localizedDescription)"
                            AppLogger.logError(error, context: "Batch delete from server - receipt \(receiptNumber)")
                            return (errorMsg, receiptNumber) // Error
                        }
                    }
                }
                
                for await result in group {
                    results.append(result)
                }
                
                return results
            }
            
            // Process results on main actor
            await MainActor.run {
                let deletionErrors = deletionResults.compactMap { $0.0 }
                
                // Delete all locally (even if some server deletions failed)
                for receipt in receiptsToDelete {
                    context.delete(receipt)
                }
                saveContext()
                loadReceipts()
                isLoading = false
                
                if !deletionErrors.isEmpty {
                    errorMessage = "Some receipts failed to delete from server: \(deletionErrors.joined(separator: ", "))"
                    AppLogger.logWarning("Batch deletion completed with errors: \(deletionErrors)", context: "ReceiptStore")
                } else {
                    AppLogger.logDataOperation("Batch deletion completed successfully for \(receiptsToDelete.count) receipts", success: true)
                }
            }
        }
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
        
        // Get all local receipts
        let localRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        let localReceipts: [Receipt]
        do {
            localReceipts = try context.fetch(localRequest)
        } catch {
            AppLogger.logError(error, context: "Failed to fetch local receipts for sync")
            return
        }
        
        // Create a set of server receipt numbers for quick lookup
        let serverReceiptNumbers = Set(serverReceipts.map { $0.transactionNumber })
        
        // 1. Remove local receipts that no longer exist on server
        for localReceipt in localReceipts {
            if let receiptNumber = localReceipt.receiptNumber,
               !serverReceiptNumbers.contains(receiptNumber) {
                AppLogger.logDataOperation("Removing locally deleted receipt: \(receiptNumber)", success: true)
                context.delete(localReceipt)
            }
        }
        
        // 2. Add/update receipts from server
        for serverReceipt in serverReceipts {
            // Check if receipt already exists locally using transaction number
            let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
            request.predicate = NSPredicate(format: "receiptNumber == %@", serverReceipt.transactionNumber)
            
            do {
                let existingReceipts = try context.fetch(request)
                if existingReceipts.isEmpty {
                    // Create new receipt from server data
                    AppLogger.logDataOperation("Creating new receipt from server: \(serverReceipt.transactionNumber)", success: true)
                    createReceiptFromServerData(serverReceipt, context: context)
                } else {
                    // Update existing receipt
                    AppLogger.logDataOperation("Updating existing receipt from server: \(serverReceipt.transactionNumber)", success: true)
                    updateReceiptFromServerData(existingReceipts.first!, serverReceipt: serverReceipt)
                }
            } catch {
                AppLogger.logError(error, context: "Receipt sync individual item")
            }
        }
        
        saveContext()
        loadReceipts()
        
        AppLogger.logDataOperation("Receipt sync completed: \(serverReceipts.count) server receipts processed", success: true)
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
    
    func uploadReceiptToServer(pdfData: Data, fileName: String) async throws {
        // Check upload limits for free users
        let accountService = AccountService.shared
        if !accountService.canUploadReceipts {
            throw ReceiptUploadError.uploadLimitReached
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let serverReceipt = try await APIService.shared.uploadReceipt(pdfData: pdfData, fileName: fileName)
            
            await MainActor.run {
                self.isLoading = false
                self.syncServerReceipts([serverReceipt])
                
                // Refresh account data to update receipt count
                accountService.refreshAccountData()
                
                // Send notification for successful upload processing
                // NotificationManager.shared.sendReceiptProcessingComplete(
                //     receiptNumber: serverReceipt.transactionNumber,
                //     itemCount: serverReceipt.items.count
                // )
            }
        } catch APIService.APIError.uploadSuccessButNoData {
            // This is actually a success case - the upload worked but the server didn't return parseable data
            // This is common when the server returns a simple success message instead of full receipt data
            AppLogger.logDataOperation("Upload successful but no receipt data returned", success: true)
            await MainActor.run {
                self.isLoading = false
                // Clear any existing error messages since this is success
                self.errorMessage = nil
                // Refresh account data to update receipt count
                accountService.refreshAccountData()
                // Don't add any fake receipt data - just let the user know it succeeded
                // The actual receipt will appear when we sync with the server later
            }
            // Don't throw the error - this is success
            return
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
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
        dateFormatter.dateFormat = "MMM" // Just month name, e.g., "Oct"
        
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
                // Use stored category if available, otherwise extract from item name
                let category = lineItem.category ?? extractCategory(from: lineItem.name ?? "")
                categorySpending[category, default: 0] += lineItem.price * Double(lineItem.quantity)
            }
        }
        
        return categorySpending
    }
    
    // MARK: - Category Extraction
    
    private func extractCategory(from description: String) -> String {
        let desc = description.lowercased()
        
        // Return "Other" for empty descriptions
        guard !desc.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Other"
        }
        
        // Food & Groceries - most common at Costco
        // Includes Costco abbreviations: CHKN=chicken, BF=beef, ORG=organic, etc.
        let foodKeywords = [
            // Meat & Protein
            "chicken", "chkn", "beef", "pork", "salmon", "fish", "tuna", "shrimp", "meat",
            "steak", "bacon", "sausage", "ham", "turkey", "lamb", "rib", "roast", "ground",
            "rotisserie", "deli", "lunchmeat",
            // Bakery & Bread
            "bread", "bagel", "croissant", "muffin", "tortilla", "bun", "roll", "bakery", "cake", "pie", "donut",
            // Grains & Pasta
            "pasta", "rice", "quinoa", "oatmeal", "cereal", "granola", "flour", "noodle",
            // Dairy
            "milk", "cheese", "yogurt", "butter", "cream", "egg", "dairy", "creamer",
            // Oils & Cooking
            "olive", "oil", "xvoo", "evoo", "coconut", "avocado oil", "cooking", "spray",
            // Nuts & Snacks
            "nut", "almond", "cashew", "peanut", "walnut", "pistachio", "trail mix", "mixed nuts",
            "chip", "chips", "popcorn", "pretzel", "cracker", "snack",
            // Produce
            "fruit", "vegetable", "veggie", "produce", "avocado", "banana", "apple", "orange",
            "berry", "grape", "mango", "lettuce", "spinach", "kale", "broccoli", "carrot",
            "tomato", "onion", "potato", "salad", "organic", "org ",
            // Frozen
            "frozen", "pizza", "ice cream", "icecream",
            // Pantry
            "soup", "sauce", "salsa", "hummus", "dip", "spread", "honey", "syrup", "jam",
            "jelly", "peanut butter", "almond butter", "canned", "can ",
            // Sweets
            "cookie", "chocolate", "candy", "sweet", "sugar",
            // Protein bars & supplements (food category)
            "protein bar", "granola bar", "bar ", "bars",
            // General food terms
            "food", "meal", "dinner", "lunch", "breakfast", "entree"
        ]
        
        // Beverages
        let beverageKeywords = [
            "water", "h2o", "sparkling", "soda", "coke", "pepsi", "sprite", "cola",
            "juice", "lemonade", "tea", "coffee", "espresso", "latte",
            "wine", "beer", "vodka", "whiskey", "tequila", "rum", "liquor", "alcohol",
            "la croix", "lacroix", "pellegrino", "evian", "fiji", "dasani", "aquafina",
            "gatorade", "redbull", "red bull", "monster", "energy drink",
            "drink", "beverage", "kombucha"
        ]
        
        // Household & Cleaning
        let householdKeywords = [
            // Paper products (common Costco abbreviations)
            "paper towel", "paper twl", "tp ", "toilet", "tissue", "napkin", "kleenex",
            "charmin", "bounty", "scott", "cottonelle",
            // Cleaning
            "detergent", "laundry", "dishwasher", "dish ", "dishes", "soap",
            "cleaner", "cleaning", "clean ", "wipe", "wipes", "disinfect",
            "lysol", "clorox", "tide", "cascade", "dawn", "swiffer", "mr clean",
            // Storage & Trash
            "trash bag", "garbage", "ziploc", "glad", "hefty", "bag ", "bags",
            "foil", "plastic wrap", "parchment", "wrap", "container",
            // Costco abbreviations
            "hh ", "household"
        ]
        
        // Health & Personal Care
        let healthKeywords = [
            // Vitamins & Supplements
            "vitamin", "vit ", "supplement", "probiotic", "omega", "fish oil", "calcium",
            "multivitamin", "mineral",
            // Medicine
            "medicine", "tylenol", "advil", "ibuprofen", "aspirin", "pain", "cold", "flu",
            "allergy", "zyrtec", "claritin", "benadryl",
            // Personal care
            "shampoo", "conditioner", "body wash", "lotion", "moisturizer",
            "toothpaste", "toothbrush", "floss", "mouthwash", "oral-b", "crest", "colgate",
            "deodorant", "razor", "shave", "shaving", "sunscreen", "spf",
            "bandage", "first aid", "band-aid",
            // Costco abbreviations
            "hba", "health", "personal care"
        ]
        
        // Baby & Kids
        let babyKeywords = [
            "diaper", "huggies", "pampers", "luvs", "baby wipe", "baby food",
            "formula", "infant", "toddler", "baby", "kid", "child", "children"
        ]
        
        // Pet Supplies
        let petKeywords = [
            "dog", "cat", "pet", "puppy", "kitten", "canine", "feline",
            "kibble", "treats", "litter", "leash", "collar", "chew"
        ]
        
        // Electronics & Tech
        let electronicsKeywords = [
            "tv", "television", "laptop", "computer", "tablet", "ipad", "iphone",
            "phone", "airpods", "headphone", "earbuds", "speaker", "camera",
            "battery", "batteries", "charger", "cable", "usb", "hdmi", "cord",
            "printer", "ink", "toner", "electronics", "tech", "samsung", "lg", "sony", "apple"
        ]
        
        // Home & Kitchen
        let homeKeywords = [
            "towel", "sheet", "pillow", "blanket", "bedding", "mattress", "bed ",
            "cookware", "pan", "pot", "knife", "utensil", "spatula", "cutting board",
            "blender", "mixer", "instant pot", "air fryer", "vacuum", "dyson",
            "light bulb", "bulb", "led ", "extension", "storage", "furniture",
            "kitchen", "home ", "house"
        ]
        
        // Clothing & Apparel
        let clothingKeywords = [
            "shirt", "pants", "shorts", "dress", "jacket", "coat", "sweater",
            "sock", "underwear", "bra", "shoe", "sandal", "slipper", "boot",
            "clothing", "apparel", "wear", "jeans", "polo"
        ]
        
        // Check categories - order matters (most specific first)
        if containsKeyword(desc, keywords: babyKeywords) {
            return "Baby & Kids"
        }
        if containsKeyword(desc, keywords: petKeywords) {
            return "Pet Supplies"
        }
        if containsKeyword(desc, keywords: electronicsKeywords) {
            return "Electronics"
        }
        if containsKeyword(desc, keywords: healthKeywords) {
            return "Health & Personal Care"
        }
        if containsKeyword(desc, keywords: householdKeywords) {
            return "Household"
        }
        if containsKeyword(desc, keywords: homeKeywords) {
            return "Home & Kitchen"
        }
        if containsKeyword(desc, keywords: clothingKeywords) {
            return "Clothing"
        }
        if containsKeyword(desc, keywords: beverageKeywords) {
            return "Beverages"
        }
        if containsKeyword(desc, keywords: foodKeywords) {
            return "Food & Groceries"
        }
        
        // If it contains "KS" or "KIRKLAND" it's likely food
        if desc.contains("ks ") || desc.contains("kirkland") {
            return "Food & Groceries"
        }
        
        return "Other"
    }
    
    private func containsKeyword(_ text: String, keywords: [String]) -> Bool {
        return keywords.contains { keyword in
            text.contains(keyword)
        }
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

// MARK: - Receipt Upload Errors

enum ReceiptUploadError: Error, LocalizedError {
    case uploadLimitReached
    
    var errorDescription: String? {
        switch self {
        case .uploadLimitReached:
            return "Upload limit reached. Upgrade to Premium for unlimited uploads."
        }
    }
} 