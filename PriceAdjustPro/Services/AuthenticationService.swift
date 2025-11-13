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
        currentUser = user
        isAuthenticated = true
        errorMessage = nil
        
        // Debug: Print account type information
        print("=== SUBSCRIPTION DEBUG ===")
        print("User authenticated: \(user.email)")
        print("Raw account type from API: '\(user.accountType ?? "nil")'")
        print("Is paid user: \(user.isPaidUser)")
        print("Is free user: \(user.isFreeUser)")
        print("Receipt count: \(user.receiptCount ?? 0)")
        print("Receipt limit: \(user.receiptLimit ?? 0)")
        print("==========================")
        
        // Notify AccountService about authentication
        NotificationCenter.default.post(name: .userDidAuthenticate, object: user)
        
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

// MARK: - Note: Using separate BiometricAuthService.swift file

// MARK: - Temporary BiometricAuthService (until separate file is added to build target)
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var biometricType: LABiometryType = .none
    @Published var biometricError: String?
    @Published var isBiometricEnabled: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let biometricEnabledKey = "biometric_auth_enabled"
    private let storedCredentialsKey = "stored_credentials"
    
    private init() {
        checkBiometricAvailability()
        loadBiometricPreference()
    }
    
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        AppLogger.logSecurityEvent("Checking biometric availability...")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            AppLogger.logSecurityEvent("Biometric available: \(biometricTypeString) (type: \(biometricType.rawValue))")
        } else {
            biometricType = .none
            let errorDescription = error?.localizedDescription ?? "Unknown error"
            biometricError = errorDescription
            AppLogger.logWarning("Biometric not available: \(errorDescription)", context: "BiometricAuth")
        }
    }
    
    var isBiometricAvailable: Bool {
        let available = biometricType != .none
        AppLogger.logSecurityEvent("isBiometricAvailable called - type: \(biometricType.rawValue), available: \(available)")
        return available
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        @unknown default:
            return "Biometric Authentication"
        }
    }
    
    private func loadBiometricPreference() {
        isBiometricEnabled = userDefaults.bool(forKey: biometricEnabledKey)
        AppLogger.logSecurityEvent("Loaded biometric preference - enabled: \(isBiometricEnabled)")
    }
    
    func setBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        userDefaults.set(enabled, forKey: biometricEnabledKey)
        
        if !enabled {
            clearStoredCredentials()
        }
    }
    
    func storeCredentials(email: String, password: String, isInitialSetup: Bool = false) -> Bool {
        if !isInitialSetup {
            guard isBiometricEnabled else { 
                AppLogger.logWarning("Attempted to store credentials when biometric auth is disabled", context: "BiometricAuth")
                return false 
            }
        }
        
        AppLogger.logSecurityEvent("Attempting to store biometric credentials for: \(email)")
        let credentials = ["email": email, "password": password]
        
        do {
            let data = try JSONEncoder().encode(credentials)
            AppLogger.logSecurityEvent("Credentials encoded successfully, attempting keychain storage")
            
            let success = KeychainHelper.save(data: data, forKey: storedCredentialsKey)
            
            if success {
                AppLogger.logSecurityEvent("Biometric credentials stored successfully")
            } else {
                AppLogger.logError(BiometricError.keychainStorageFailed, context: "Store credentials")
            }
            
            return success
        } catch {
            AppLogger.logError(error, context: "Encode credentials for storage")
            return false
        }
    }
    
    func getStoredCredentials() async -> (email: String, password: String)? {
        guard isBiometricEnabled else { return nil }
        
        do {
            let success = try await authenticateWithBiometrics(reason: "Access your saved login credentials")
            
            if success {
                guard let data = KeychainHelper.load(forKey: storedCredentialsKey) else {
                    AppLogger.logWarning("No stored credentials found", context: "Biometric auth")
                    return nil
                }
                
                let credentials = try JSONDecoder().decode([String: String].self, from: data)
                
                guard let email = credentials["email"],
                      let password = credentials["password"] else {
                    AppLogger.logError(BiometricError.invalidCredentialFormat, context: "Parse stored credentials")
                    return nil
                }
                
                AppLogger.logSecurityEvent("Biometric credentials retrieved successfully")
                return (email: email, password: password)
            } else {
                return nil
            }
        } catch {
            await MainActor.run {
                biometricError = error.localizedDescription
            }
            AppLogger.logError(error, context: "Retrieve stored credentials")
            return nil
        }
    }
    
    private func clearStoredCredentials() {
        KeychainHelper.delete(forKey: storedCredentialsKey)
        AppLogger.logSecurityEvent("Biometric credentials cleared")
    }
    
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            await MainActor.run {
                biometricError = nil
            }
            
            AppLogger.logSecurityEvent("Biometric authentication \(success ? "successful" : "failed")")
            return success
        } catch {
            await MainActor.run {
                biometricError = error.localizedDescription
            }
            AppLogger.logError(error, context: "Biometric authentication")
            throw error
        }
    }
    
    func setupBiometricAuth(email: String, password: String, skipValidation: Bool = false) async -> Bool {
        AppLogger.logSecurityEvent("setupBiometricAuth called for: \(email), skipValidation: \(skipValidation)")
        
        guard isBiometricAvailable else {
            AppLogger.logWarning("Biometric not available: \(biometricType)", context: "BiometricAuth")
            await MainActor.run {
                biometricError = "Biometric authentication is not available on this device"
            }
            return false
        }
        
        AppLogger.logSecurityEvent("Biometric available: \(biometricTypeString)")
        
        // Skip credential validation if called from post-login flow
        if !skipValidation {
            AppLogger.logSecurityEvent("Validating credentials before storing for biometric auth")
            
            let isValidCredentials = await validateCredentials(email: email, password: password)
            
            if !isValidCredentials {
                AppLogger.logWarning("Credential validation failed for biometric setup", context: "BiometricAuth")
                await MainActor.run {
                    biometricError = "Invalid password. Please enter your correct account password."
                }
                return false
            }
        } else {
            AppLogger.logSecurityEvent("Skipping credential validation (called from post-login flow)")
        }
        
        do {
            AppLogger.logSecurityEvent("Requesting biometric authentication for setup")
            let success = try await authenticateWithBiometrics(
                reason: "Enable \(biometricTypeString) for quick and secure login"
            )
            
            AppLogger.logSecurityEvent("Biometric authentication result: \(success)")
            
            if success {
                AppLogger.logSecurityEvent("Attempting to store credentials in keychain")
                let stored = storeCredentials(email: email, password: password, isInitialSetup: true)
                AppLogger.logSecurityEvent("Credential storage result: \(stored)")
                
                if stored {
                    await MainActor.run {
                        setBiometricEnabled(true)
                    }
                    AppLogger.logSecurityEvent("Biometric authentication setup completed successfully")
                    return true
                } else {
                    AppLogger.logError(BiometricError.keychainStorageFailed, context: "Failed to store credentials in keychain")
                    await MainActor.run {
                        biometricError = "Failed to securely store credentials in keychain"
                    }
                    return false
                }
            } else {
                AppLogger.logWarning("User cancelled biometric authentication setup", context: "BiometricAuth")
                await MainActor.run {
                    biometricError = "Biometric authentication setup was cancelled"
                }
                return false
            }
        } catch let error as LAError {
            // Handle specific LocalAuthentication errors
            let errorMessage: String
            switch error.code {
            case .userCancel:
                errorMessage = "Setup was cancelled"
            case .userFallback:
                errorMessage = "User chose to use passcode instead"
            case .systemCancel:
                errorMessage = "System cancelled the setup"
            case .biometryNotAvailable:
                errorMessage = "\(biometricTypeString) is not available"
            case .biometryNotEnrolled:
                errorMessage = "\(biometricTypeString) is not set up. Please set it up in Settings first."
            case .biometryLockout:
                errorMessage = "\(biometricTypeString) is locked. Please unlock it in Settings."
            default:
                errorMessage = error.localizedDescription
            }
            
            AppLogger.logError(error, context: "Biometric authentication setup failed with LA error: \(error.code.rawValue)")
            await MainActor.run {
                biometricError = errorMessage
            }
            return false
        } catch {
            AppLogger.logError(error, context: "Biometric authentication setup failed with unknown error")
            await MainActor.run {
                biometricError = error.localizedDescription
            }
            return false
        }
    }
    
    private func validateCredentials(email: String, password: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = APIService.shared.login(email: email, password: password)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(_) = completion {
                            continuation.resume(returning: false)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        if response.isError || response.user == nil {
                            continuation.resume(returning: false)
                        } else {
                            AppLogger.logSecurityEvent("Credentials validated successfully for biometric setup")
                            continuation.resume(returning: true)
                        }
                        cancellable?.cancel()
                    }
                )
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case keychainStorageFailed
    case invalidCredentialFormat
    case biometricNotAvailable
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .keychainStorageFailed:
            return "Failed to securely store credentials"
        case .invalidCredentialFormat:
            return "Invalid credential format"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .authenticationFailed:
            return "Biometric authentication failed"
        }
    }
}

struct KeychainHelper {
    static func save(data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
    
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}