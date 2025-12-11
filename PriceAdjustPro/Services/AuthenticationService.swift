import Foundation
import SwiftUI
import Combine
import LocalAuthentication
import KeychainAccess

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: APIUserResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsEmailVerification = false
    @Published var pendingVerificationEmail: String?
    
    private let keychain = Keychain(service: "com.priceadjustpro.ios")
    private let userDefaults = UserDefaults.standard
    var cancellables = Set<AnyCancellable>()
    
    var accessToken: String? {
        return keychain["access_token"]
    }
    
    private var refreshToken: String? {
        return keychain["refresh_token"]
    }
    
    init() {
        checkAuthenticationStatus()
    }
    
    private func checkAuthenticationStatus() {
        // Check if we have stored tokens
        if let _ = accessToken, let _ = refreshToken {
            // Try to refresh the token to validate it's still valid
            refreshAccessToken()
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleAuthenticationSuccess(response, email: email, password: password)
                }
            )
            .store(in: &cancellables)
    }
    
    func register(email: String, password: String, firstName: String, lastName: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.register(email: email, password: password, firstName: firstName, lastName: lastName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleAuthenticationSuccess(response)
                }
            )
            .store(in: &cancellables)
    }
    
    func logout() {
        // Clear tokens from storage
        try? keychain.remove("access_token")
        try? keychain.remove("refresh_token")
        
        // Clear biometric credentials on logout
        let biometricService = BiometricAuthService.shared
        if biometricService.isBiometricEnabled {
            biometricService.setBiometricEnabled(false)
        }
        
        // Clear user state
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        // Notify AccountService about logout
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    func deleteAccount(password: String) {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.deleteAccount(password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        AppLogger.logError(error, context: "Account deletion")
                        // Show more specific error message based on the error type
                        if case .serverError(400) = error {
                            self?.errorMessage = "Invalid password. Please enter your correct account password."
                        } else if case .serverError(404) = error {
                            self?.errorMessage = "Account deletion endpoint not available. Please contact support to delete your account."
                        } else if case .serverError(let code) = error {
                            self?.errorMessage = "Server error (\(code)). Please try again or contact support."
                        } else {
                            self?.errorMessage = "Failed to delete account: \(error.localizedDescription). Please contact support if this persists."
                        }
                    }
                },
                receiveValue: { [weak self] _ in
                    // Account successfully deleted - logout and clear all data
                    AppLogger.logDataOperation("Account deleted successfully", success: true)
                    self?.logout()
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshAccessToken() {
        guard let refreshToken = refreshToken else {
            logout()
            return
        }
        
        APIService.shared.refreshToken(refreshToken: refreshToken)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(_) = completion {
                        // Refresh failed, logout user
                        self?.logout()
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleAuthenticationSuccess(response)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleAuthenticationSuccess(_ response: APIAuthResponse, email: String? = nil, password: String? = nil) {
        // Check if this is actually an error response
        if response.isError {
            errorMessage = response.errorMessage
            print("Login failed: \(response.errorMessage ?? "Unknown error")")
            return
        }
        
        // Handle registration response that requires verification
        if response.needsVerification {
            needsEmailVerification = true
            pendingVerificationEmail = response.email ?? email ?? ""
            
            // Create a temporary user object for the registration
            if let responseEmail = response.email ?? email {
                let tempUser = APIUserResponse(
                    id: 0, // Temporary ID
                    username: response.username,
                    email: responseEmail,
                    firstName: nil,
                    lastName: nil,
                    accountType: "free",
                    receiptCount: 0,
                    receiptLimit: 5,
                    isEmailVerified: false
                )
                currentUser = tempUser
            }
            
            AppLogger.logSecurityEvent("Registration successful, email verification required for: \(response.email ?? email ?? "unknown")")
            isAuthenticated = false
            isLoading = false
            return
        }
        
        // Check if we have a valid user (which indicates successful auth even without tokens)
        guard let user = response.user else {
            errorMessage = "Invalid authentication response"
            print("Login failed: No user data received")
            return
        }

        // Some endpoints (notably token refresh) may return a partial user payload.
        // Preserve previously-known fields (e.g. account_type/premium) so the UI doesn't
        // temporarily regress to free limits after refresh.
        let mergedUser: APIUserResponse = {
            guard let existing = currentUser else { return user }
            
            func accountTypeIndicatesPaid(_ type: String?) -> Bool {
                guard let type, !type.isEmpty else { return false }
                let t = type.lowercased()
                return t == "paid" ||
                       t == "premium" ||
                       t == "pro" ||
                       t == "subscription" ||
                       t == "active" ||
                       t == "subscriber"
            }
            
            func accountTypeIndicatesFree(_ type: String?) -> Bool {
                guard let type, !type.isEmpty else { return true }
                let t = type.lowercased()
                return t == "free" ||
                       t == "basic" ||
                       t == "trial" ||
                       t == "inactive"
            }
            
            // If we already know the user is paid, don't let a refresh response "downgrade"
            // us to free via a stale/partial payload.
            let existingIsPaid = accountTypeIndicatesPaid(existing.accountType)
            let incomingAccountType: String? = {
                guard let incoming = user.accountType, !incoming.isEmpty else { return nil }
                if existingIsPaid && accountTypeIndicatesFree(incoming) && !accountTypeIndicatesPaid(incoming) {
                    return existing.accountType
                }
                return incoming
            }()
            
            return APIUserResponse(
                id: user.id != 0 ? user.id : existing.id,
                username: user.username ?? existing.username,
                email: user.email,
                firstName: user.firstName ?? existing.firstName,
                lastName: user.lastName ?? existing.lastName,
                accountType: incomingAccountType ?? existing.accountType,
                receiptCount: user.receiptCount ?? existing.receiptCount,
                // Same downgrade-prevention for limits: keep "unlimited" if we already had it.
                receiptLimit: (existingIsPaid && !accountTypeIndicatesPaid(incomingAccountType) && user.receiptLimit != nil)
                    ? existing.receiptLimit
                    : (user.receiptLimit ?? existing.receiptLimit),
                isEmailVerified: user.isEmailVerified ?? existing.isEmailVerified
            )
        }()
        
        // Check if email verification is needed (for login with unverified account)
        if user.isEmailVerified == false && password != nil {
            // User logged in but hasn't verified email yet
            needsEmailVerification = true
            pendingVerificationEmail = user.email
            AppLogger.logSecurityEvent("Login successful but email not verified for: \(user.email)")
            
            // Store user temporarily but don't fully authenticate
            currentUser = user
            isAuthenticated = false
            isLoading = false
            return
        }
        
        // Store tokens in keychain if available (for JWT-based auth)
        if let accessToken = response.accessToken {
            keychain["access_token"] = accessToken
        }
        if let refreshToken = response.refresh {
            keychain["refresh_token"] = refreshToken
        }
        
        // Store credentials for biometric auth if provided and biometric is available
        if let email = email, let password = password {
            // Always store session credentials for potential biometric use
            biometricSetupEmail = email
            biometricSetupPassword = password
            
            AppLogger.logSecurityEvent("Stored session credentials for potential biometric setup: \(email)")
            
            // Only update stored credentials if biometric is already enabled
            Task {
                let biometricService = BiometricAuthService.shared
                
                if biometricService.isBiometricEnabled {
                    // Update stored credentials for existing biometric users
                    AppLogger.logSecurityEvent("Biometric already enabled, updating stored credentials")
                    _ = biometricService.storeCredentials(email: email, password: password)
                }
            }
        }
        
        // Update user state
        currentUser = mergedUser
        isAuthenticated = true
        errorMessage = nil
        
        // Debug: Print account type information
        print("=== SUBSCRIPTION DEBUG ===")
        print("User authenticated: \(mergedUser.email)")
        print("Raw account type from API: '\(mergedUser.accountType ?? "nil")'")
        print("Is paid user: \(mergedUser.isPaidUser)")
        print("Is free user: \(mergedUser.isFreeUser)")
        print("Receipt count: \(mergedUser.receiptCount ?? 0)")
        print("Receipt limit: \(mergedUser.receiptLimit ?? 0)")
        print("==========================")
        
        // Notify AccountService about authentication
        NotificationCenter.default.post(name: .userDidAuthenticate, object: mergedUser)
        
        AppLogger.logSecurityEvent("Login successful for user: \(user.username ?? user.email)")
        if response.accessToken != nil {
            AppLogger.logSecurityEvent("Authentication token received")
        } else {
            AppLogger.logSecurityEvent("Using session-based authentication")
        }
    }
    
    func resetPassword(email: String) {
        // Implement password reset functionality
        // This would typically send a request to your backend
        isLoading = true
        errorMessage = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
            // Handle success or error
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Email Verification
    
    func updateUserVerificationStatus(user: APIUserResponse) {
        currentUser = user
        AppLogger.logSecurityEvent("User verification status updated: \(user.email) - verified: \(user.isEmailVerified ?? false)")
    }
    
    func completeEmailVerification() {
        // Mark as fully authenticated after email verification
        needsEmailVerification = false
        pendingVerificationEmail = nil
        isAuthenticated = true
        
        AppLogger.logSecurityEvent("Email verification completed successfully")
        
        // Notify about successful authentication
        if let user = currentUser {
            NotificationCenter.default.post(name: .userDidAuthenticate, object: user)
        }
    }
    
    func skipEmailVerification() {
        // Allow user to continue with limited access
        // They can still verify later from settings
        needsEmailVerification = false
        pendingVerificationEmail = nil
        isAuthenticated = true
        
        AppLogger.logWarning("User skipped email verification", context: "Authentication")
        
        // Notify about authentication (with unverified status)
        if let user = currentUser {
            NotificationCenter.default.post(name: .userDidAuthenticate, object: user)
        }
    }
    
    // MARK: - Biometric Authentication
    
    @Published var biometricSetupEmail: String?
    @Published var biometricSetupPassword: String?
    
    func getLastLoginCredentials() -> (email: String, password: String)? {
        guard let email = biometricSetupEmail,
              let password = biometricSetupPassword else {
            return nil
        }
        return (email: email, password: password)
    }
    
    func loginWithBiometrics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let biometricService = BiometricAuthService.shared
                
                guard let credentials = await biometricService.getStoredCredentials() else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Unable to retrieve stored credentials"
                    }
                    return
                }
                
                // Use the retrieved credentials to login
                await MainActor.run {
                    login(email: credentials.email, password: credentials.password)
                }
            }
        }
    }
    
    
    
}

// MARK: - Keychain Extension

extension Keychain {
    subscript(key: String) -> String? {
        get {
            return try? get(key)
        }
        set {
            if let value = newValue {
                try? set(value, key: key)
            } else {
                try? remove(key)
            }
        }
    }
}