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
        case uploadSuccessButNoData
        
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
            case .uploadSuccessButNoData:
                return "Upload successful"
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
        
        AppLogger.apiCall("POST", to: url.absoluteString)
        
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
                AppLogger.logResponseData(data, from: url.absoluteString)
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
                    AppLogger.logDataOperation("User response decoded", success: true)
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
                    AppLogger.logError(decodingError, context: "User response decoding")
                    
                    // If that fails, try to decode as normal auth response
                    if let authResponse = try? decoder.decode(APIAuthResponse.self, from: data) {
                        AppLogger.logDataOperation("Auth response decoded", success: true)
                        return authResponse
                    }
                    
                    AppLogger.logError(APIError.decodingError, context: "Auth response decoding")
                    throw APIError.decodingError
                }
            }
            .mapError { error in
                if error is DecodingError {
                    AppLogger.logError(error, context: "API response decoding")
                    return APIError.decodingError
                } else {
                    AppLogger.logError(error, context: "API network request")
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
    
    func uploadReceipt(pdfData: Data, fileName: String) async throws -> ReceiptResponse {
        guard let url = URL(string: "\(baseURL)/receipts/upload/") else {
            throw APIError.invalidURL
        }
        
        return try await uploadFile(url: url, fileData: pdfData, fileName: fileName, fieldName: "receipt_file")
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
    
    func deleteReceipt(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/receipts/\(id)/") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // Django session-based auth uses cookies, not Authorization headers
        
        do {
            let (_, httpResponse) = try await urlSession.data(for: request)
            
            // Check HTTP status code
            if let httpResponse = httpResponse as? HTTPURLResponse {
                AppLogger.apiSuccess(httpResponse.statusCode, from: url.absoluteString)
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    AppLogger.logError(APIError.serverError(httpResponse.statusCode), context: "Delete receipt HTTP status")
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
        } catch {
            AppLogger.logError(error, context: "Delete receipt network request")
            throw APIError.networkError(error)
        }
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
                        AppLogger.logWarning("CSRF request failed, trying without CSRF protection", context: "API request")
                        // If CSRF fails, try without CSRF (some Django views can be exempt)
                        return self.performRequest(url: url, method: "PATCH", body: updateData)
                    }
                    .eraseToAnyPublisher()
            }
            .catch { [weak self] error -> AnyPublisher<ReceiptResponse, APIError> in
                AppLogger.logWarning("CSRF token acquisition failed, trying direct request", context: "API request")
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
                AppLogger.logResponseData(data, from: url.absoluteString)
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .map { response in
                return response
            }
            .mapError { error in
                if error is DecodingError {
                    AppLogger.logError(error, context: "API response decoding")
                    return APIError.decodingError
                } else {
                    AppLogger.logError(error, context: "API network request")
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
        
        AppLogger.apiCall(method, to: url.absoluteString)
        AppLogger.logSecurityEvent("Using CSRF token for request")
        
        if let body = body {
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(body)
                request.httpBody = jsonData
                AppLogger.logRequestBody(jsonData)
            } catch {
                AppLogger.logError(error, context: "Request body encoding")
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    AppLogger.apiSuccess(httpResponse.statusCode, from: url.absoluteString)
                    
                    if httpResponse.statusCode >= 400 {
                        AppLogger.logResponseData(data, from: url.absoluteString)
                        throw APIError.serverError(httpResponse.statusCode)
                    }
                }
                return data
            }
            .handleEvents(receiveOutput: { data in
                AppLogger.logResponseData(data, from: url.absoluteString)
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    AppLogger.logError(error, context: "CSRF API response decoding")
                    return APIError.decodingError
                } else if let apiError = error as? APIError {
                    AppLogger.logError(apiError, context: "CSRF API request")
                    return apiError
                } else {
                    AppLogger.logError(error, context: "CSRF network request")
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
                AppLogger.logRequestBody(jsonData)
            } catch {
                AppLogger.logError(error, context: "Request body encoding")
                return Fail(error: APIError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return urlSession.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                AppLogger.logResponseData(data, from: url.absoluteString)
            })
            .decode(type: T.self, decoder: JSONDecoder())
            .map { response in
                return response
            }
            .mapError { error in
                if error is DecodingError {
                    AppLogger.logError(error, context: "API response decoding")
                    return APIError.decodingError
                } else {
                    AppLogger.logError(error, context: "API network request")
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
    ) async throws -> ReceiptResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Django session-based auth uses cookies, not Authorization headers
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add file data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        
        // Determine content type based on file extension
        let contentType: String
        if fileName.lowercased().hasSuffix(".pdf") {
            contentType = "application/pdf"
        } else if fileName.lowercased().hasSuffix(".jpg") || fileName.lowercased().hasSuffix(".jpeg") {
            contentType = "image/jpeg"
        } else if fileName.lowercased().hasSuffix(".png") {
            contentType = "image/png"
        } else {
            contentType = "application/octet-stream"
        }
        
        data.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = data
        
        do {
            let (responseData, httpResponse) = try await urlSession.data(for: request)
            
            // Check HTTP status code
            if let httpResponse = httpResponse as? HTTPURLResponse {
                AppLogger.apiSuccess(httpResponse.statusCode, from: url.absoluteString)
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    AppLogger.logError(APIError.serverError(httpResponse.statusCode), context: "Upload file HTTP status")
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Log the raw response first
            AppLogger.logResponseData(responseData, from: url.absoluteString)
            
            // Check if response is empty
            if responseData.isEmpty {
                print("⚠️ Server returned empty response body with HTTP 200 - upload successful but no data returned")
                // Since upload was successful (HTTP 200), we'll just throw a specific success error
                // that the calling code can catch and handle as a success case
                throw APIError.uploadSuccessButNoData
            }
            
            // Try to decode the response
            do {
                let receiptResponse = try JSONDecoder().decode(ReceiptResponse.self, from: responseData)
                return receiptResponse
            } catch {
                print("❌ Decoding error: \(error)")
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("📄 Raw server response: \(responseString)")
                }
                AppLogger.logError(error, context: "Upload file response decoding")
                
                // Since we got HTTP 200, the upload was successful but we can't decode the response
                // This is likely a success case, so we'll throw a special error indicating success
                throw APIError.uploadSuccessButNoData
            }
        } catch {
            AppLogger.logError(error, context: "Upload file network request")
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Models 