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
    
    func storeCredentials(email: String, password: String) -> Bool {
        guard isBiometricEnabled else { return false }
        
        let credentials = ["email": email, "password": password]
        
        do {
            let data = try JSONEncoder().encode(credentials)
            let success = KeychainHelper.save(data: data, forKey: storedCredentialsKey)
            
            if success {
                AppLogger.logSecurityEvent("Biometric credentials stored")
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
    
    func setupBiometricAuth(email: String, password: String) async -> Bool {
        guard isBiometricAvailable else {
            await MainActor.run {
                biometricError = "Biometric authentication is not available on this device"
            }
            return false
        }
        
        do {
            let success = try await authenticateWithBiometrics(
                reason: "Enable \(biometricTypeString) for quick and secure login"
            )
            
            if success {
                let stored = storeCredentials(email: email, password: password)
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