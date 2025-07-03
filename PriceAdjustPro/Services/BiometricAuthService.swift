import Foundation
import LocalAuthentication
import Combine

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
    
    // MARK: - Biometric Availability
    
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
    
    // MARK: - Biometric Settings
    
    private func loadBiometricPreference() {
        isBiometricEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }
    
    func setBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        userDefaults.set(enabled, forKey: biometricEnabledKey)
        
        if !enabled {
            // Clear stored credentials when biometric auth is disabled
            clearStoredCredentials()
        }
    }
    
    // MARK: - Credential Storage
    
    func storeCredentials(email: String, password: String, isInitialSetup: Bool = false) -> Bool {
        // During initial setup, we don't check isBiometricEnabled since we're in the process of enabling it
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
            // First authenticate with biometrics
            let success = try await authenticateWithBiometrics(reason: "Access your saved login credentials")
            
            if success {
                // Retrieve credentials from keychain
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
    
    // MARK: - Biometric Authentication
    
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
    
    // MARK: - Setup Biometric Auth
    
    func enableBiometricWithoutPassword(email: String) async -> Bool {
        guard isBiometricAvailable else {
            await MainActor.run {
                biometricError = "Biometric authentication is not available on this device"
            }
            return false
        }
        
        // Check if credentials are already stored
        if let data = KeychainHelper.load(forKey: storedCredentialsKey) {
            do {
                let credentials = try JSONDecoder().decode([String: String].self, from: data)
                guard let storedEmail = credentials["email"] else {
                    await MainActor.run {
                        biometricError = "Invalid stored credentials format"
                    }
                    return false
                }
                
                // Verify the stored credentials match the current user
                if storedEmail != email {
                    await MainActor.run {
                        biometricError = "Stored credentials don't match current user"
                    }
                    return false
                }
                
                // Just enable biometric authentication using existing credentials
                setBiometricEnabled(true)
                AppLogger.logSecurityEvent("Biometric authentication enabled without password prompt")
                return true
                
            } catch {
                await MainActor.run {
                    biometricError = "Failed to process stored credentials"
                }
                AppLogger.logError(error, context: "Enable biometric without password")
                return false
            }
        } else {
            // No stored credentials - this means the user needs to set up biometric auth first
            // We'll just enable the setting and let the login flow handle credential storage
            setBiometricEnabled(true)
            AppLogger.logSecurityEvent("Biometric authentication enabled - credentials will be stored on next login")
            return true
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
            
            // Test the credentials with the server
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
                        // Check if this is actually an error response
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

// MARK: - Biometric Errors

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

// MARK: - Keychain Helper

struct KeychainHelper {
    static func save(data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
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