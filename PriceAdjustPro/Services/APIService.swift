import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://priceadjustpro.onrender.com/api"
    private var cancellables = Set<AnyCancellable>()
    private var csrfToken: String?
    
    // Use a shared URLSession with cookie storage for Django session authentication
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()
    
    enum APIError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError
        case serverError(Int)
        case networkError(Error)
        case csrfError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .decodingError:
                return "Failed to decode response"
            case .serverError(let code):
                return "Server error: \(code)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .csrfError:
                return "CSRF token error"
            }
        }
    }
    
    private init() {}
    
    // MARK: - CSRF Token Management
    
    private func getCSRFToken() -> AnyPublisher<String, APIError> {
        // Try multiple common Django CSRF endpoints
        let possibleEndpoints = [
            "\(baseURL)/csrf/",
            "\(baseURL)/get-csrf-token/",
            "\(baseURL)/auth/csrf/"
        ]
        
        // Try each endpoint until one works
        return possibleEndpoints.publisher
            .setFailureType(to: APIError.self)
            .flatMap { endpoint -> AnyPublisher<String, APIError> in
                guard let url = URL(string: endpoint) else {
                    return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                return self.urlSession.dataTaskPublisher(for: request)
                    .tryMap { data, response -> String in
                        if let httpResponse = response as? HTTPURLResponse {
                            // Look for CSRF token in cookies first
                            if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                                for cookie in cookies {
                                    if cookie.name == "csrftoken" {
                                        return cookie.value
                                    }
                                }
                            }
                            
                            // Try to parse from response headers
                            if let csrfToken = httpResponse.allHeaderFields["X-CSRFToken"] as? String {
                                return csrfToken
                            }
                            
                            // Try to parse from JSON response
                            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let csrfToken = jsonObject["csrfToken"] as? String {
                                return csrfToken
                            }
                        }
                        
                        throw APIError.csrfError
                    }
                    .mapError { error in
                        if let apiError = error as? APIError {
                            return apiError
                        } else {
                            return APIError.networkError(error)
                        }
                    }
                    .eraseToAnyPublisher()
            }
            .first() // Take the first successful result
            .eraseToAnyPublisher()
    }
    
    private func ensureCSRFToken() -> AnyPublisher<String, APIError> {
        if let token = csrfToken {
            return Just(token)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        } else {
            return getCSRFToken()
                .handleEvents(receiveOutput: { [weak self] token in
                    self?.csrfToken = token
                })
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Authentication API
    
    func login(email: String, password: String) -> AnyPublisher<APIAuthResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/login/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        print("Making login request to: \(url)")
        
        let loginData = LoginRequest(username: email, password: password)
        
        return performLoginRequest(url: url, body: loginData)
    }
    
    private func performLoginRequest(url: URL, body: LoginRequest) -> AnyPublisher<APIAuthResponse, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: APIError.decodingError)
                .eraseToAnyPublisher()
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)")
                }
            })
            .tryMap { data -> APIAuthResponse in
                let decoder = JSONDecoder()
                
                // First check if this is an error response by looking for "error" field
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = jsonObject["error"] as? String {
                    return APIAuthResponse(
                        access: nil,
                        refresh: nil,
                        user: nil,
                        key: nil,
                        token: nil,
                        error: errorMessage,
                        detail: nil
                    )
                }
                
                // Try to decode as direct user response first (more specific)
                do {
                    let userResponse = try decoder.decode(APIUserResponse.self, from: data)
                    print("Decoded as user response: \(userResponse)")
                    // Create an auth response with the user but no tokens
                    return APIAuthResponse(
                        access: nil,
                        refresh: nil,
                        user: userResponse,
                        key: nil,
                        token: nil,
                        error: nil,
                        detail: nil
                    )
                } catch let decodingError {
                    print("Failed to decode as user response: \(decodingError)")
                    
                    // If that fails, try to decode as normal auth response
                    if let authResponse = try? decoder.decode(APIAuthResponse.self, from: data) {
                        print("Decoded as auth response: \(authResponse)")
                        return authResponse
                    }
                    
                    print("Failed to decode as any known response type")
                    throw APIError.decodingError
                }
            }
            .mapError { error in
                if error is DecodingError {
                    print("Decoding error: \(error)")
                    return APIError.decodingError
                } else {
                    print("Network error: \(error)")
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func register(email: String, password: String, firstName: String, lastName: String) -> AnyPublisher<APIAuthResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/register/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let registerData = RegisterRequest(email: email, password: password, firstName: firstName, lastName: lastName)
        
        return performRequest(url: url, method: "POST", body: registerData)
    }
    
    func refreshToken(refreshToken: String) -> AnyPublisher<APIAuthResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/auth/refresh/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let refreshData = RefreshTokenRequest(refresh: refreshToken)
        
        return performRequest(url: url, method: "POST", body: refreshData)
    }
    
    // MARK: - Price Adjustments API
    
    func getPriceAdjustments() -> AnyPublisher<PriceAdjustmentsResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/price-adjustments/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performRequestWithoutBody(url: url, method: "GET")
    }
    
    func dismissPriceAdjustment(itemCode: String) -> AnyPublisher<Void, APIError> {
        guard let url = URL(string: "\(baseURL)/price-adjustments/dismiss/\(itemCode)/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performVoidRequest(url: url, method: "POST", body: Optional<String>.none)
    }
    
    // MARK: - On Sale API
    
    func getOnSaleItems() -> AnyPublisher<OnSaleResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/on-sale/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performRequestWithoutBody(url: url, method: "GET")
    }
    
    // MARK: - Dashboard Analytics API
    
    func getAnalytics() -> AnyPublisher<AnalyticsResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/analytics/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performRequestWithoutBody(url: url, method: "GET")
    }
    
    // MARK: - Receipt API
    
    func uploadReceipt(pdfData: Data, fileName: String) -> AnyPublisher<ReceiptResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/receipts/upload/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return uploadFile(url: url, fileData: pdfData, fileName: fileName, fieldName: "receipt_file")
    }
    
    func getReceipts() -> AnyPublisher<[ReceiptResponse], APIError> {
        guard let url = URL(string: "\(baseURL)/receipts/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performRequestWithoutBody(url: url, method: "GET")
            .map { (response: ReceiptsListResponse) in
                return response.receipts
            }
            .eraseToAnyPublisher()
    }
    
    func getReceiptDetail(id: String) -> AnyPublisher<ReceiptResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/receipts/\(id)/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performRequestWithoutBody(url: url, method: "GET")
    }
    
    func deleteReceipt(id: String) -> AnyPublisher<Void, APIError> {
        guard let url = URL(string: "\(baseURL)/receipts/\(id)/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return performVoidRequest(url: url, method: "DELETE", body: Optional<String>.none)
    }
    
        func updateReceipt(transactionNumber: String, updateData: UpdateReceiptRequest) -> AnyPublisher<ReceiptResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/receipts/\(transactionNumber)/") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        // Try with CSRF token first, then fallback to simpler approach
        return ensureCSRFToken()
            .flatMap { [weak self] csrfToken -> AnyPublisher<ReceiptResponse, APIError> in
                guard let self = self else {
                    return Fail(error: APIError.csrfError).eraseToAnyPublisher()
                }
                
                return self.performRequestWithCSRF(url: url, method: "PATCH", body: updateData, csrfToken: csrfToken)
                    .catch { error -> AnyPublisher<ReceiptResponse, APIError> in
                        print("⚠️ CSRF request failed, trying without CSRF protection...")
                        // If CSRF fails, try without CSRF (some Django views can be exempt)
                        return self.performRequest(url: url, method: "PATCH", body: updateData)
                    }
                    .eraseToAnyPublisher()
            }
            .catch { [weak self] error -> AnyPublisher<ReceiptResponse, APIError> in
                print("⚠️ CSRF token acquisition failed, trying direct request...")
                // If we can't get CSRF token at all, try direct request
                guard let self = self else {
                    return Fail(error: APIError.csrfError).eraseToAnyPublisher()
                }
                return self.performRequest(url: url, method: "PATCH", body: updateData)
            }
            .eraseToAnyPublisher()
    }
    
    private func getCSRFTokenFromCookies() -> String? {
        guard let url = URL(string: baseURL),
              let cookies = HTTPCookieStorage.shared.cookies(for: url) else {
            return nil
        }
        
        for cookie in cookies {
            if cookie.name == "csrftoken" {
                return cookie.value
            }
        }
        return nil
    }
    
    // MARK: - Generic Request Methods
    
    private func performRequestWithoutBody<T: Codable>(
        url: URL,
        method: String
    ) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Django session-based auth uses cookies, not Authorization headers
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response for \(url): \(jsonString)")
                }
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    print("Decoding error for \(url): \(error)")
                    return APIError.decodingError
                } else {
                    print("Network error for \(url): \(error)")
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performRequest<T: Codable, U: Codable>(
        url: URL,
        method: String,
        body: U? = nil
    ) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Django session-based auth uses cookies, not Authorization headers
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                // Debug logging to see actual response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)")
                }
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .map { response in
                return response
            }
            .mapError { error in
                if error is DecodingError {
                    print("Decoding error: \(error)")
                    return APIError.decodingError
                } else {
                    print("Network error: \(error)")
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performRequestWithCSRF<T: Codable, U: Codable>(
        url: URL,
        method: String,
        body: U? = nil,
        csrfToken: String
    ) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")
        
        // Add Referer header as required by Django CSRF protection
        request.setValue(baseURL, forHTTPHeaderField: "Referer")
        
        // Django session-based auth uses cookies, not Authorization headers
        
        print("🌐 Making \(method) request to: \(url)")
        print("🔐 Using CSRF token: \(csrfToken)")
        print("📤 Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        if let body = body {
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(body)
                request.httpBody = jsonData
                
                if let bodyString = String(data: jsonData, encoding: .utf8) {
                    print("📤 Request body: \(bodyString)")
                }
            } catch {
                print("❌ Failed to encode request body: \(error)")
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .handleEvents(receiveSubscription: { _ in
                print("🚀 Request started")
            })
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 Response status: \(httpResponse.statusCode)")
                    print("📥 Response headers: \(httpResponse.allHeaderFields)")
                    
                    if httpResponse.statusCode >= 400 {
                        print("❌ HTTP Error \(httpResponse.statusCode)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        throw APIError.serverError(httpResponse.statusCode)
                    }
                }
                return data
            }
            .handleEvents(receiveOutput: { data in
                // Debug logging to see actual response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("✅ API Response: \(jsonString)")
                }
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    print("❌ Decoding error: \(error)")
                    return APIError.decodingError
                } else if let apiError = error as? APIError {
                    print("❌ API error: \(apiError)")
                    return apiError
                } else {
                    print("❌ Network error: \(error)")
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performRequestWithReferer<T: Codable, U: Codable>(
        url: URL,
        method: String,
        body: U? = nil
    ) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Referer header as required by Django CSRF protection
        request.setValue(baseURL, forHTTPHeaderField: "Referer")
        
        // Django session-based auth uses cookies, not Authorization headers
        
        if let body = body {
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(body)
                request.httpBody = jsonData
                

            } catch {
                print("Failed to encode request body: \(error)")
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                // Debug logging to see actual response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)")
                }
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .map { response in
                return response
            }
            .mapError { error in
                if error is DecodingError {
                    print("Decoding error: \(error)")
                    return APIError.decodingError
                } else {
                    print("Network error: \(error)")
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performVoidRequest<U: Codable>(
        url: URL,
        method: String,
        body: U? = nil
    ) -> AnyPublisher<Void, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Django session-based auth uses cookies, not Authorization headers
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .map { _ in () }
            .mapError { error in
                APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    private func uploadFile(
        url: URL,
        fileData: Data,
        fileName: String,
        fieldName: String
    ) -> AnyPublisher<ReceiptResponse, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Django session-based auth uses cookies, not Authorization headers
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add file data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = data
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ReceiptResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - API Models 