import Foundation
import StoreKit
import Combine

@MainActor
class StoreKitService: NSObject, ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs - these should match your App Store Connect configuration
    private let productIDs = ["com.priceadjustpro.monthly", "com.priceadjustpro.yearly"]
    
    private var updates: Task<Void, Never>? = nil
    
    override init() {
        super.init()
        
        // Start listening for transaction updates
        updates = listenForTransactions()
        
        // Load products and current entitlements
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIDs)
            if products.isEmpty {
                // No products found in App Store Connect - show helpful message
                errorMessage = "Products not configured in App Store Connect yet. Please set up subscription products with IDs: \(productIDs.joined(separator: ", "))"
                AppLogger.logWarning("No products found in App Store Connect", context: "StoreKit product loading")
            } else {
                self.products = products.sorted { $0.price < $1.price }
                AppLogger.logDataOperation("Loaded \(products.count) products from App Store", success: true)
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            AppLogger.logError(error, context: "StoreKit product loading")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    
    func purchase(_ product: Product) async throws -> Transaction? {
        AppLogger.user("Attempting to purchase: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try await checkVerified(verification)
            
            // Sync with backend
            do {
                try await SubscriptionSyncService.shared.syncPurchaseWithBackend(transaction)
            } catch {
                AppLogger.logError(error, context: "Backend sync after purchase")
                // Continue with local update even if backend sync fails
            }
            
            await updatePurchasedProducts()
            await transaction.finish()
            
            AppLogger.user("Successfully purchased: \(product.displayName)")
            return transaction
            
        case .userCancelled:
            AppLogger.user("User cancelled purchase")
            return nil
            
        case .pending:
            AppLogger.user("Purchase is pending")
            return nil
            
        default:
            AppLogger.logError(NSError(domain: "StoreKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]), context: "Purchase")
            return nil
        }
    }
    
    func restorePurchases() async {
        AppLogger.user("Restoring purchases")
        
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - Subscription Status
    
    func updatePurchasedProducts() async {
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                purchasedProducts.insert(transaction.productID)
            } catch {
                AppLogger.logError(error, context: "Transaction verification")
            }
        }
        
        purchasedProductIDs = purchasedProducts
        
        // Update account service
        let isPremium = !purchasedProducts.isEmpty
        updateAccountServiceWithPremiumStatus(isPremium)
        
        AppLogger.logDataOperation("Updated purchased products: \(purchasedProducts)", success: true)
    }
    
    private func updateAccountServiceWithPremiumStatus(_ isPremium: Bool) {
        // Update the account service to reflect premium status
        if let currentUser = AccountService.shared.currentUser {
            let updatedUser = APIUserResponse(
                id: currentUser.id,
                username: currentUser.username,
                email: currentUser.email,
                firstName: currentUser.firstName,
                lastName: currentUser.lastName,
                accountType: isPremium ? "premium" : "free",
                receiptCount: currentUser.receiptCount,
                receiptLimit: isPremium ? nil : 5,
                isEmailVerified: currentUser.isEmailVerified
            )
            AccountService.shared.updateUser(updatedUser)
        }
    }
    
    // MARK: - Transaction Listening
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    AppLogger.logError(error, context: "Transaction update")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Convenience Properties
    
    var isPremiumUser: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    var monthlyProduct: Product? {
        products.first { $0.id == "com.priceadjustpro.monthly" }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == "com.priceadjustpro.yearly" }
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
