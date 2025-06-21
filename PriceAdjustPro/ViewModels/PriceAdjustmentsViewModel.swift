import Foundation
import Combine

class PriceAdjustmentsViewModel: ObservableObject {
    @Published var adjustments: [PriceAdjustment] = []
    @Published var totalPotentialSavings: Double = 0.0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadPriceAdjustments() {
        isLoading = true
        errorMessage = nil
        
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
} 