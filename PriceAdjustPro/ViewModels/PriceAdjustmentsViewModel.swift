import Foundation
import Combine
import UserNotifications

class PriceAdjustmentsViewModel: ObservableObject {
    @Published var adjustments: [PriceAdjustment] = []
    @Published var totalPotentialSavings: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var previousAdjustmentsCount = 0
    private var checkTimer: Timer?
    
    func loadPriceAdjustments() {
        isLoading = true
        errorMessage = nil
        previousAdjustmentsCount = adjustments.count
        
        APIService.shared.getPriceAdjustments()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("Error loading price adjustments: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.checkForNewPriceAdjustments(newAdjustments: response.adjustments)
                    self?.adjustments = response.adjustments
                    self?.totalPotentialSavings = response.totalPotentialSavings
                }
            )
            .store(in: &cancellables)
    }
    
    func dismissAdjustment(_ itemCode: String, completion: @escaping (Bool, String) -> Void) {
        APIService.shared.dismissPriceAdjustment(itemCode: itemCode)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        completion(true, "Price adjustment dismissed successfully")
                    case .failure(let error):
                        completion(false, "Failed to dismiss price adjustment: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] _ in
                    // Remove the dismissed adjustment from the list
                    if let index = self?.adjustments.firstIndex(where: { $0.itemCode == itemCode }) {
                        let dismissedAdjustment = self?.adjustments[index]
                        self?.adjustments.remove(at: index)
                        
                        // Update total savings
                        if let priceDifference = dismissedAdjustment?.priceDifference {
                            self?.totalPotentialSavings -= priceDifference
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Functions
    
    private func checkForNewPriceAdjustments(newAdjustments: [PriceAdjustment]) {
        // This method is only used for UI updates now - daily checking handles notifications
        // Just update the previous count for tracking
        previousAdjustmentsCount = newAdjustments.count
    }
    
    // MARK: - Daily Checking
    
    func checkForPriceAdjustments() {
        // Simple check - just fetch current adjustments and notify if any exist
        APIService.shared.getPriceAdjustments()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.logError(error, context: "Daily price adjustment check")
                    }
                },
                receiveValue: { response in
                    // If there are any price adjustments, send notification
                    if !response.adjustments.isEmpty {
                        AppLogger.logDataOperation("Found \(response.adjustments.count) price adjustments worth $\(String(format: "%.2f", response.totalPotentialSavings))", success: true)
                        
                        // Post notification to main app for handling
                        NotificationCenter.default.post(
                            name: .priceAdjustmentFound,
                            object: nil,
                            userInfo: [
                                "count": response.adjustments.count,
                                "totalSavings": response.totalPotentialSavings
                            ]
                        )
                    } else {
                        AppLogger.logDataOperation("No price adjustments found during daily check", success: true)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func startDailyChecking() {
        // Check once a day for price adjustments (24 hours = 86400 seconds)
        checkTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            AppLogger.logDataOperation("Running daily price adjustment check", success: true)
            self?.checkForPriceAdjustments()
        }
        
        AppLogger.logDataOperation("Started daily price adjustment checking", success: true)
    }
    
    func stopDailyChecking() {
        checkTimer?.invalidate()
        checkTimer = nil
        AppLogger.logDataOperation("Stopped daily price adjustment checking", success: true)
    }
    
    deinit {
        stopDailyChecking()
    }
} 