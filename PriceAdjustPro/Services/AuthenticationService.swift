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
    
    private let keychain = Keychain(service: "com.priceadjustpro.ios")
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // Check if we have a valid user (which indicates successful auth even without tokens)
        guard let user = response.user else {
            errorMessage = "Invalid authentication response"
            print("Login failed: No user data received")
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
            
            Task {
                let biometricService = BiometricAuthService.shared
                if biometricService.isBiometricAvailable && !biometricService.isBiometricEnabled {
                    // Ask user if they want to enable biometric auth
                    await offerBiometricSetup(email: email, password: password)
                } else if biometricService.isBiometricEnabled {
                    // Update stored credentials
                    _ = biometricService.storeCredentials(email: email, password: password)
                }
            }
        }
        
        // Update user state
        currentUser = user
        isAuthenticated = true
        errorMessage = nil
        
        print("Login successful for user: \(user.username ?? user.email)")
        if let token = response.accessToken {
            print("With token: \(token.prefix(20))...")
        } else {
            print("Using session-based authentication")
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
    
    // MARK: - Biometric Authentication
    
    @Published var shouldOfferBiometricSetup = false
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
    
    private func offerBiometricSetup(email: String, password: String) async {
        await MainActor.run {
            biometricSetupEmail = email
            biometricSetupPassword = password
            shouldOfferBiometricSetup = true
        }
    }
    
    func enableBiometricAuth() {
        guard let email = biometricSetupEmail,
              let password = biometricSetupPassword else { 
            AppLogger.logWarning("No stored credentials for biometric setup", context: "BiometricAuth")
            return 
        }
        
        AppLogger.logSecurityEvent("Starting biometric auth setup for user: \(email)")
        
        Task {
            let biometricService = BiometricAuthService.shared
            // Skip credential validation since user just logged in successfully
            let success = await biometricService.setupBiometricAuth(email: email, password: password, skipValidation: true)
            
            await MainActor.run {
                shouldOfferBiometricSetup = false
                biometricSetupEmail = nil
                biometricSetupPassword = nil
                
                if !success {
                    let errorMsg = biometricService.biometricError ?? "Failed to enable biometric authentication"
                    AppLogger.logWarning("Biometric setup failed: \(errorMsg)", context: "BiometricAuth")
                    errorMessage = errorMsg
                }
            }
        }
    }
    
    func declineBiometricAuth() {
        shouldOfferBiometricSetup = false
        biometricSetupEmail = nil
        biometricSetupPassword = nil
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
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            biometricError = error?.localizedDescription
        }
    }
    
    var isBiometricAvailable: Bool {
        return biometricType != .none
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
        guard isBiometricAvailable else {
            await MainActor.run {
                biometricError = "Biometric authentication is not available on this device"
            }
            return false
        }
        
        // Skip credential validation if called from post-login flow
        if !skipValidation {
            AppLogger.logSecurityEvent("Validating credentials before storing for biometric auth")
            
            let isValidCredentials = await validateCredentials(email: email, password: password)
            
            if !isValidCredentials {
                await MainActor.run {
                    biometricError = "Invalid password. Please enter your correct account password."
                }
                return false
            }
        } else {
            AppLogger.logSecurityEvent("Skipping credential validation (called from post-login flow)")
        }
        
        do {
            let success = try await authenticateWithBiometrics(
                reason: "Enable \(biometricTypeString) for quick and secure login"
            )
            
            if success {
                let stored = storeCredentials(email: email, password: password, isInitialSetup: true)
                if stored {
                    setBiometricEnabled(true)
                    AppLogger.logSecurityEvent("Biometric authentication setup completed")
                    return true
                } else {
                    await MainActor.run {
                        biometricError = "Failed to securely store credentials"
                    }
                    return false
                }
            } else {
                return false
            }
        } catch {
            await MainActor.run {
                biometricError = error.localizedDescription
            }
            AppLogger.logError(error, context: "Setup biometric auth")
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