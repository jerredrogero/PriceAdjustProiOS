import Foundation
import SwiftUI
import Combine
import KeychainAccess

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: APIUserResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychain = Keychain(service: "com.priceadjustpro.ios")
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
                    self?.handleAuthenticationSuccess(response)
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
        // Clear tokens from keychain
        keychain["access_token"] = nil
        keychain["refresh_token"] = nil
        
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
    
    private func handleAuthenticationSuccess(_ response: APIAuthResponse) {
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