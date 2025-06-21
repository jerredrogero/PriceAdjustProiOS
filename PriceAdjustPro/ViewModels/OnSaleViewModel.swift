import Foundation
import Combine

class OnSaleViewModel: ObservableObject {
    @Published var sales: [SaleItem] = []
    @Published var activePromotions: [Promotion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    let categories = [
        "All",
        "Food & Beverages",
        "Electronics", 
        "Health & Beauty",
        "Household & Cleaning",
        "Clothing",
        "Home & Garden",
        "Baby & Kids",
        "Automotive",
        "Other"
    ]
    
    func loadSales() {
        isLoading = true
        errorMessage = nil
        
        APIService.shared.getOnSaleItems()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("Error loading sales: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.sales = response.sales
                    self?.activePromotions = response.activePromotions
                }
            )
            .store(in: &cancellables)
    }
} 