import Foundation
import Combine
import SwiftUI

@MainActor
class AccountService: ObservableObject {
    static let shared = AccountService()
    
    @Published var currentUser: APIUserResponse?
    @Published var showUpgradePrompt = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Listen for authentication changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidAuthenticate),
            name: .userDidAuthenticate,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidLogout),
            name: .userDidLogout,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - User Updates
    
    func updateUser(_ user: APIUserResponse) {
        currentUser = user
        
        // Debug: Print account service information
        print("AccountService: User updated")
        print("AccountService: Account type: \(user.accountType ?? "nil")")
        print("AccountService: Is paid user: \(isPaidUser)")
        print("AccountService: Is free user: \(isFreeUser)")
        print("AccountService: Can upload receipts: \(canUploadReceipts)")
        print("AccountService: Has reached limit: \(hasReachedReceiptLimit)")
    }
    
    @objc private func userDidAuthenticate(notification: Notification) {
        if let user = notification.object as? APIUserResponse {
            print("AccountService: Received authentication notification")
            updateUser(user)
        } else {
            print("AccountService: Authentication notification received but no user data")
        }
    }
    
    @objc private func userDidLogout() {
        currentUser = nil
    }
    
    // MARK: - Account Type Checks
    
    /// True when StoreKit indicates an active subscription entitlement.
    /// This is used as a source of truth for "Premium" so the UI doesn't regress
    /// to free limits if the backend user payload is stale.
    private var hasPremiumEntitlement: Bool {
        StoreKitService.shared.isPremiumUser
    }
    
    var isPaidUser: Bool {
        return (currentUser?.isPaidUser ?? false) || hasPremiumEntitlement
    }
    
    var isFreeUser: Bool {
        if isPaidUser { return false }
        return currentUser?.isFreeUser ?? true
    }
    
    var accountTypeDisplayName: String {
        return isPaidUser ? "Premium" : "Free"
    }
    
    // MARK: - Receipt Limits
    
    var receiptLimit: Int {
        if isPaidUser { return Int.max }
        return currentUser?.receiptLimit ?? 5
    }
    
    var receiptCount: Int {
        return currentUser?.receiptCount ?? 0
    }
    
    var remainingReceiptUploads: Int {
        if isPaidUser { return Int.max }
        return currentUser?.remainingReceiptUploads ?? max(0, receiptLimit - receiptCount)
    }
    
    var hasReachedReceiptLimit: Bool {
        if isPaidUser { return false }
        return currentUser?.hasReachedReceiptLimit ?? false
    }
    
    var receiptLimitProgress: Double {
        if isPaidUser { return 0.0 }
        guard receiptLimit > 0 else { return 0.0 }
        return Double(receiptCount) / Double(receiptLimit)
    }
    
    // MARK: - Feature Access
    
    var canUploadReceipts: Bool {
        return isPaidUser || !hasReachedReceiptLimit
    }
    
    var canAccessAnalytics: Bool {
        return true // Analytics available to all users
    }
    
    var canAccessPriceAdjustments: Bool {
        return true // Available to all users
    }
    
    var canAccessOnSaleItems: Bool {
        return true // Available to all users
    }
    
    // MARK: - Upgrade Prompts
    
    func showUpgradePromptIfNeeded(for feature: String) {
        if isFreeUser {
            showUpgradePrompt = true
        }
    }
    
    func checkReceiptUploadLimit() -> Bool {
        if isPaidUser {
            return true
        }
        
        if isFreeUser && hasReachedReceiptLimit {
            showUpgradePrompt = true
            return false
        }
        return true
    }
    
    // MARK: - Refresh Account Data
    
    func refreshAccountData() {
        // This would typically make an API call to refresh user data
        // For now, we'll rely on the authentication service to update user data
        AuthenticationService.shared.refreshAccessToken()
    }
    
    // MARK: - Account Status Messages
    
    func getReceiptLimitMessage() -> String {
        if isPaidUser {
            return "Unlimited receipt uploads"
        } else {
            return "\(remainingReceiptUploads) of \(receiptLimit) uploads remaining"
        }
    }
    
    func getAnalyticsAccessMessage() -> String {
        return "Available to all users"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidAuthenticate = Notification.Name("userDidAuthenticate")
    static let userDidLogout = Notification.Name("userDidLogout")
} 