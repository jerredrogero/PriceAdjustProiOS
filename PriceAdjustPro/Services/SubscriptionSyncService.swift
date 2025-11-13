import Foundation
import StoreKit

@MainActor
class SubscriptionSyncService: ObservableObject {
    static let shared = SubscriptionSyncService()
    
    private let apiService = APIService.shared
    private let storeKitService = StoreKitService.shared
    
    private init() {}
    
    // MARK: - Sync Purchase with Backend
    
    /// Syncs a successful in-app purchase with the Django backend
    func syncPurchaseWithBackend(_ transaction: Transaction) async throws {
        guard let receiptData = await getReceiptData() else {
            throw SubscriptionError.noReceiptData
        }
        
        let purchaseData = ApplePurchaseData(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            receiptData: receiptData.base64EncodedString(),
            originalTransactionId: String(transaction.originalID),
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate
        )
        
        try await sendPurchaseToBackend(purchaseData)
        
        AppLogger.logDataOperation("Successfully synced purchase with backend: \(transaction.productID)", success: true)
    }
    
    /// Validates subscription status with backend
    func validateSubscriptionStatus() async throws -> SubscriptionStatus {
        guard let receiptData = await getReceiptData() else {
            throw SubscriptionError.noReceiptData
        }
        
        let validationRequest = ReceiptValidationRequest(
            receiptData: receiptData.base64EncodedString()
        )
        
        return try await apiService.validateAppleReceipt(validationRequest)
    }
    
    // MARK: - Private Methods
    
    private func getReceiptData() async -> Data? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            AppLogger.logError(SubscriptionError.noReceiptData, context: "Receipt data retrieval")
            return nil
        }
        
        return try? Data(contentsOf: receiptURL)
    }
    
    private func sendPurchaseToBackend(_ purchaseData: ApplePurchaseData) async throws {
        let endpoint = "/subscriptions/apple/purchase/"
        let url = URL(string: "https://priceadjustpro.onrender.com/api" + endpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use session-based authentication (cookies) like the rest of the app
        // Django session-based auth uses cookies from HTTPCookieStorage
        // If you switch to token-based auth in the future, uncomment below:
        // if let token = apiService.getAuthToken() {
        //     request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(purchaseData)
        
        // Use shared URLSession with cookie storage (same as APIService)
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SubscriptionError.backendError(errorMessage)
        }
    }
}

// MARK: - Data Models

struct ApplePurchaseData: Codable {
    let transactionId: String
    let productId: String
    let receiptData: String
    let originalTransactionId: String
    let purchaseDate: Date
    let expirationDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case productId = "product_id"
        case receiptData = "receipt_data"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expirationDate = "expiration_date"
    }
}

struct ReceiptValidationRequest: Codable {
    let receiptData: String
    
    enum CodingKeys: String, CodingKey {
        case receiptData = "receipt_data"
    }
}

struct SubscriptionStatus: Codable {
    let isActive: Bool
    let productId: String?
    let expirationDate: Date?
    let subscriptionType: String?
    
    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case productId = "product_id"
        case expirationDate = "expiration_date"
        case subscriptionType = "subscription_type"
    }
}

// MARK: - Errors

enum SubscriptionError: Error, LocalizedError {
    case noReceiptData
    case invalidResponse
    case backendError(String)
    
    var errorDescription: String? {
        switch self {
        case .noReceiptData:
            return "No receipt data available"
        case .invalidResponse:
            return "Invalid response from server"
        case .backendError(let message):
            return "Backend error: \(message)"
        }
    }
}
