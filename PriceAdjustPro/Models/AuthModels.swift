import Foundation

struct APIUserResponse: Codable {
    let id: Int
    let username: String?
    let email: String
    let firstName: String?
    let lastName: String?
    let accountType: String?
    let receiptCount: Int?
    let receiptLimit: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case accountType = "account_type"
        case receiptCount = "receipt_count"
        case receiptLimit = "receipt_limit"
    }
    
    // Computed properties for account management
    var isPaidUser: Bool {
        guard let accountType = accountType else { return false }
        let lowercasedType = accountType.lowercased()
        
        // Check for various possible values that indicate a paid account
        return lowercasedType == "paid" || 
               lowercasedType == "premium" || 
               lowercasedType == "pro" || 
               lowercasedType == "subscription" ||
               lowercasedType == "active" ||
               lowercasedType == "subscriber"
    }
    
    var isFreeUser: Bool {
        guard let accountType = accountType else { return true }
        let lowercasedType = accountType.lowercased()
        
        // Check for various possible values that indicate a free account
        return lowercasedType == "free" || 
               lowercasedType == "basic" || 
               lowercasedType == "trial" ||
               lowercasedType == "inactive"
    }
    
    var remainingReceiptUploads: Int {
        guard let limit = receiptLimit, let count = receiptCount else { 
            return isFreeUser ? 5 : Int.max
        }
        return max(0, limit - count)
    }
    
    var hasReachedReceiptLimit: Bool {
        guard let limit = receiptLimit, let count = receiptCount else {
            return false
        }
        return count >= limit
    }
}

struct APIAuthResponse: Codable {
    let access: String?
    let refresh: String?
    let user: APIUserResponse?
    
    // Handle different possible response formats
    let key: String? // django-rest-auth format
    let token: String? // alternative format
    
    // Error handling
    let error: String?
    let detail: String?
    
    enum CodingKeys: String, CodingKey {
        case access, refresh, user, key, token, error, detail
    }
    
    // Computed property to get the actual access token
    var accessToken: String? {
        return access ?? key ?? token
    }
    
    // Check if this is an error response
    var isError: Bool {
        return error != nil || detail != nil
    }
    
    var errorMessage: String? {
        return error ?? detail ?? "Authentication failed"
    }
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct RefreshTokenRequest: Codable {
    let refresh: String
} 