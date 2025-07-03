import Foundation
import Combine

class PriceAdjustmentsViewModel: ObservableObject {
    @Published var adjustments: [PriceAdjustment] = []
    @Published var totalPotentialSavings: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var previousAdjustmentsCount = 0
    
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
        // Only send notifications if we have more adjustments than before and it's not the initial load
        guard previousAdjustmentsCount > 0 && newAdjustments.count > previousAdjustmentsCount else { return }
        
        let newAdjustmentsCount = newAdjustments.count - previousAdjustmentsCount
        AppLogger.logDataOperation("Found \(newAdjustmentsCount) new price adjustments", success: true)
        
        // Get the new adjustments
        let newItems = Array(newAdjustments.suffix(newAdjustmentsCount))
        
        // Send notifications for significant price drops (> $10)
        let _ = newItems.filter { $0.priceDifference > 10.0 }
        
        // TODO: Re-enable when NotificationManager is added to target
        // for adjustment in significantAdjustments.prefix(3) { // Limit to 3 to avoid spam
        //     NotificationManager.shared.sendPriceDropAlert(
        //         itemName: adjustment.description,
        //         oldPrice: adjustment.currentPrice,
        //         newPrice: adjustment.lowerPrice
        //     )
        // }
        
        // Send general price adjustment notification if there are any new ones
        if !newItems.isEmpty {
            let totalNewSavings = newItems.reduce(0) { $0 + $1.priceDifference }
            AppLogger.logDataOperation("New price adjustments: \(newAdjustmentsCount) items worth $\(String(format: "%.2f", totalNewSavings))", success: true)
            
            // TODO: Re-enable when NotificationManager is added to target
            // NotificationManager.shared.scheduleLocalNotification(
            //     title: "💰 Price Adjustments Available!",
            //     body: "You have \(newAdjustmentsCount) new price adjustments worth $\(String(format: "%.2f", totalNewSavings))",
            //     category: NotificationManager.NotificationCategory.priceDropAlert,
            //     userInfo: [
            //         "type": "price_adjustments",
            //         "count": newAdjustmentsCount,
            //         "total_savings": totalNewSavings
            //     ]
            // )
        }
    }
} 