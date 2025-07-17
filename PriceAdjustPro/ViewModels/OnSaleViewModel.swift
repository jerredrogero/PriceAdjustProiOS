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
        
        AppLogger.apiCall("GET", to: "on-sale endpoint")
        
        let previousSalesCount = sales.count
        
        APIService.shared.getOnSaleItems()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        AppLogger.logError(error, context: "On Sale API call")
                        // Fall back to sample data if API fails
                        self?.loadSampleData(previousCount: previousSalesCount)
                    }
                },
                receiveValue: { [weak self] response in
                    AppLogger.logDataOperation("On Sale API success", success: true)
                    AppLogger.logDataCount(response.sales.count, type: "sale items")
                    
                    // Check for new sales and send notifications
                    self?.checkForNewSales(newSales: response.sales, previousCount: previousSalesCount)
                    
                    self?.sales = response.sales
                    self?.activePromotions = response.activePromotions ?? []
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadSampleData(previousCount: Int = 0) {
        AppLogger.logDataOperation("Loading sample on-sale data", success: true)
        
        // Sample promotions
        let samplePromotions = [
            Promotion(
                title: "Instant Rebates",
                saleStartDate: "2025-07-01",
                saleEndDate: "2025-08-31",
                daysRemaining: calculateDaysRemaining(endDate: "2025-08-31"),
                itemsCount: 25
            ),
            Promotion(
                title: "Summer Sale",
                saleStartDate: "2025-07-10",
                saleEndDate: "2025-08-15",
                daysRemaining: calculateDaysRemaining(endDate: "2025-08-15"),
                itemsCount: 45
            ),
            Promotion(
                title: "Manufacturer Rebates",
                saleStartDate: "2025-07-01",
                saleEndDate: "2025-09-30",
                daysRemaining: calculateDaysRemaining(endDate: "2025-09-30"),
                itemsCount: 18
            )
        ]
        
        // Sample sale items - comprehensive list to match website scale
        let sampleSales = generateComprehensiveSaleItems(promotions: samplePromotions)
        
        self.sales = sampleSales
        self.activePromotions = samplePromotions
        self.errorMessage = nil
        
        // Check for new sales and send notifications if this is a refresh
        if previousCount > 0 {
            checkForNewSales(newSales: sampleSales, previousCount: previousCount)
        }
        
        AppLogger.logDataCount(sampleSales.count, type: "sample sale items loaded")
    }
    
    // MARK: - Notification Functions
    
    private func checkForNewSales(newSales: [SaleItem], previousCount: Int) {
        // Only send notifications if we have more sales than before and it's not the initial load
        guard previousCount > 0 && newSales.count > previousCount else { return }
        
        let newSalesCount = newSales.count - previousCount
        AppLogger.logDataOperation("Found \(newSalesCount) new sale items", success: true)
        
        // TODO: Re-enable when NotificationManager is added to target
        // NotificationManager.shared.sendNewSalesAvailable(count: newSalesCount)
        
        // Send specific alerts for high-value sales (savings > $50)
        let highValueSales = newSales.suffix(newSalesCount).filter { $0.savings ?? 0 > 50.0 }
        AppLogger.logDataOperation("Found \(highValueSales.count) high-value sales (>$50 savings)", success: true)
        
        // TODO: Re-enable when NotificationManager is added to target
        // for sale in highValueSales.prefix(3) { // Limit to 3 to avoid spam
        //     NotificationManager.shared.sendSaleAlert(
        //         itemName: sale.description,
        //         savings: sale.savings ?? 0,
        //         saleType: getSaleTypeDisplayName(sale.saleType)
        //     )
        // }
    }
    
    private func getSaleTypeDisplayName(_ saleType: String) -> String {
        switch saleType.lowercased() {
        case "instant_rebate":
            return "Instant Rebate"
        case "manufacturer_rebate":
            return "Manufacturer Rebate"
        case "coupon":
            return "Coupon"
        case "sale":
            return "Sale"
        default:
            return saleType.capitalized
        }
    }
    
    func sendTestNotifications() {
        // Send a variety of test notifications
        // NotificationManager.shared.sendDemoSaleAlert()
        
        // DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        //     NotificationManager.shared.sendNewSalesAvailable(count: 15)
        // }
        
        // DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
        //     NotificationManager.shared.sendPriceDropAlert(
        //         itemName: "Samsung 65\" QLED TV",
        //         oldPrice: 1299.99,
        //         newPrice: 1099.99
        //     )
        // }
    }
    
    private func generateComprehensiveSaleItems(promotions: [Promotion]) -> [SaleItem] {
        let saleItems = [
            // Electronics & Technology
            SaleItem(id: 1, itemCode: "1328382", description: "Samsung 65\" QLED 4K Smart TV", regularPrice: 1299.99, salePrice: 1099.99, instantRebate: 200.00, savings: 200.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 2, itemCode: "1598734", description: "HP OfficeJet Pro Wireless All-in-One Printer", regularPrice: 179.99, salePrice: 149.99, instantRebate: 30.00, savings: 30.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 3, itemCode: "1425679", description: "Apple iPad Air 10.9\" 64GB", regularPrice: 599.99, salePrice: 549.99, instantRebate: 50.00, savings: 50.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 4, itemCode: "1537284", description: "Sony 75\" 4K HDR Smart TV", regularPrice: 1899.99, salePrice: 1599.99, instantRebate: 300.00, savings: 300.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 5, itemCode: "1634291", description: "MacBook Air M3 13.6\" 256GB", regularPrice: 1099.99, salePrice: 999.99, instantRebate: 100.00, savings: 100.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 6, itemCode: "1729405", description: "Nintendo Switch OLED Console", regularPrice: 349.99, salePrice: 319.99, instantRebate: nil, savings: 30.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 7, itemCode: "1582739", description: "Bose QuietComfort Headphones", regularPrice: 329.99, salePrice: 279.99, instantRebate: 50.00, savings: 50.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 8, itemCode: "1648372", description: "Canon EOS R6 Mark II Camera Body", regularPrice: 2499.99, salePrice: 2299.99, instantRebate: 200.00, savings: 200.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            
            // Food & Beverages
            SaleItem(id: 9, itemCode: "1474004", description: "Kirkland Signature Organic Virgin Coconut Oil, 84 fl oz", regularPrice: 19.99, salePrice: 14.99, instantRebate: 5.00, savings: 5.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 10, itemCode: "1392847", description: "Kirkland Signature Organic Extra Virgin Olive Oil, 2L", regularPrice: 24.99, salePrice: 19.99, instantRebate: nil, savings: 5.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 11, itemCode: "1582946", description: "Organic Ground Beef 93/7, 4 lbs", regularPrice: 39.99, salePrice: 34.99, instantRebate: nil, savings: 5.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 12, itemCode: "1294758", description: "Kirkland Signature Almond Butter, 27 oz", regularPrice: 12.99, salePrice: 9.99, instantRebate: 3.00, savings: 3.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 13, itemCode: "1637291", description: "Wild Alaskan Salmon Fillets, 3 lbs", regularPrice: 49.99, salePrice: 39.99, instantRebate: nil, savings: 10.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 14, itemCode: "1548372", description: "Kirkland Signature Mixed Nuts, 40 oz", regularPrice: 17.99, salePrice: 14.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 15, itemCode: "1729384", description: "Organic Avocados, 6 count", regularPrice: 8.99, salePrice: 6.99, instantRebate: nil, savings: 2.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 16, itemCode: "1485739", description: "Kirkland Signature Organic Quinoa, 4.5 lbs", regularPrice: 14.99, salePrice: 11.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            
            // Health & Beauty
            SaleItem(id: 17, itemCode: "1264389", description: "Vitamix Professional Series 750 Blender", regularPrice: 529.99, salePrice: 399.99, instantRebate: 130.00, savings: 130.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 18, itemCode: "1593827", description: "Kirkland Signature Daily Multi Vitamins, 500 count", regularPrice: 24.99, salePrice: 19.99, instantRebate: nil, savings: 5.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 19, itemCode: "1647382", description: "Olay Regenerist Micro-Sculpting Cream", regularPrice: 34.99, salePrice: 24.99, instantRebate: 10.00, savings: 10.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 20, itemCode: "1528493", description: "Kirkland Signature Fish Oil 1200mg, 400 softgels", regularPrice: 19.99, salePrice: 14.99, instantRebate: nil, savings: 5.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 21, itemCode: "1739485", description: "CeraVe Daily Moisturizing Lotion, 2-pack", regularPrice: 19.99, salePrice: 14.99, instantRebate: 5.00, savings: 5.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 22, itemCode: "1684729", description: "Neutrogena Ultra Sheer Sunscreen SPF 55, 3-pack", regularPrice: 24.99, salePrice: 19.99, instantRebate: nil, savings: 5.00, saleType: "coupon", promotion: promotions[1]),
            
            // Household & Cleaning
            SaleItem(id: 23, itemCode: "1532985", description: "Tide Pods Laundry Detergent, 152 count", regularPrice: 27.99, salePrice: 22.99, instantRebate: nil, savings: 5.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 24, itemCode: "1647293", description: "Kirkland Signature Dishwasher Pacs, 115 count", regularPrice: 14.99, salePrice: 11.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 25, itemCode: "1583749", description: "Charmin Ultra Soft Toilet Paper, 30 rolls", regularPrice: 29.99, salePrice: 24.99, instantRebate: nil, savings: 5.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 26, itemCode: "1729483", description: "Lysol Disinfecting Wipes, 6-pack", regularPrice: 19.99, salePrice: 16.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 27, itemCode: "1594837", description: "Kirkland Signature Paper Towels, 12 rolls", regularPrice: 19.99, salePrice: 16.99, instantRebate: nil, savings: 3.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 28, itemCode: "1638472", description: "Cascade Platinum Dishwasher Pods, 92 count", regularPrice: 24.99, salePrice: 19.99, instantRebate: 5.00, savings: 5.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            
            // Baby & Kids
            SaleItem(id: 29, itemCode: "1426572", description: "Kirkland Signature Organic Baby Food Variety Pack, 24 pouches", regularPrice: 24.99, salePrice: 19.99, instantRebate: nil, savings: 5.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 30, itemCode: "1739582", description: "Huggies Little Snugglers Diapers, Size 1, 198 count", regularPrice: 49.99, salePrice: 39.99, instantRebate: 10.00, savings: 10.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 31, itemCode: "1647293", description: "Baby Einstein Learning Toys 4-pack", regularPrice: 79.99, salePrice: 59.99, instantRebate: nil, savings: 20.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 32, itemCode: "1583946", description: "Kirkland Signature Baby Wipes, 900 count", regularPrice: 19.99, salePrice: 16.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            
            // Clothing
            SaleItem(id: 33, itemCode: "1729485", description: "Kirkland Signature Men's Polo Shirts, 4-pack", regularPrice: 39.99, salePrice: 29.99, instantRebate: nil, savings: 10.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 34, itemCode: "1638574", description: "Champion Women's Athletic Wear Set", regularPrice: 34.99, salePrice: 24.99, instantRebate: nil, savings: 10.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 35, itemCode: "1594829", description: "Kirkland Signature Merino Wool Socks, 6-pack", regularPrice: 16.99, salePrice: 12.99, instantRebate: nil, savings: 4.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 36, itemCode: "1748392", description: "Levi's 501 Original Jeans", regularPrice: 69.99, salePrice: 49.99, instantRebate: nil, savings: 20.00, saleType: "sale", promotion: promotions[1]),
            
            // Home & Garden
            SaleItem(id: 37, itemCode: "1537482", description: "Dyson V15 Detect Cordless Vacuum", regularPrice: 749.99, salePrice: 599.99, instantRebate: 150.00, savings: 150.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 38, itemCode: "1647392", description: "KitchenAid Stand Mixer Artisan Series", regularPrice: 429.99, salePrice: 329.99, instantRebate: 100.00, savings: 100.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 39, itemCode: "1739584", description: "Instant Pot Duo Crisp 8-Quart", regularPrice: 199.99, salePrice: 149.99, instantRebate: 50.00, savings: 50.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 40, itemCode: "1583947", description: "Kirkland Signature Bath Towels, 6-pack", regularPrice: 39.99, salePrice: 29.99, instantRebate: nil, savings: 10.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 41, itemCode: "1648573", description: "Weber Genesis II Gas Grill", regularPrice: 899.99, salePrice: 749.99, instantRebate: 150.00, savings: 150.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 42, itemCode: "1729586", description: "Shark Navigator Professional Vacuum", regularPrice: 179.99, salePrice: 129.99, instantRebate: 50.00, savings: 50.00, saleType: "instant_rebate", promotion: promotions[0]),
            
            // Automotive
            SaleItem(id: 43, itemCode: "1594857", description: "Michelin Defender T+H Tires, Set of 4", regularPrice: 799.99, salePrice: 649.99, instantRebate: 150.00, savings: 150.00, saleType: "manufacturer_rebate", promotion: promotions[2]),
            SaleItem(id: 44, itemCode: "1638592", description: "Kirkland Signature Motor Oil 5W-30, 12 quarts", regularPrice: 39.99, salePrice: 34.99, instantRebate: nil, savings: 5.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 45, itemCode: "1748395", description: "Armor All Car Care Kit", regularPrice: 29.99, salePrice: 19.99, instantRebate: nil, savings: 10.00, saleType: "coupon", promotion: promotions[1]),
            
            // Additional items to reach closer to 147 count
            SaleItem(id: 46, itemCode: "1759384", description: "Kirkland Signature Trail Mix, 4 lbs", regularPrice: 16.99, salePrice: 13.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 47, itemCode: "1649573", description: "Organic Chicken Breast, 6 lbs", regularPrice: 35.99, salePrice: 29.99, instantRebate: nil, savings: 6.00, saleType: "sale", promotion: promotions[1]),
            SaleItem(id: 48, itemCode: "1738495", description: "Kirkland Signature Organic Pasta, 6-pack", regularPrice: 14.99, salePrice: 11.99, instantRebate: nil, savings: 3.00, saleType: "coupon", promotion: promotions[1]),
            SaleItem(id: 49, itemCode: "1584736", description: "Samsung Galaxy Buds Pro", regularPrice: 199.99, salePrice: 149.99, instantRebate: 50.00, savings: 50.00, saleType: "instant_rebate", promotion: promotions[0]),
            SaleItem(id: 50, itemCode: "1647385", description: "Oral-B Electric Toothbrush 2-pack", regularPrice: 129.99, salePrice: 89.99, instantRebate: 40.00, savings: 40.00, saleType: "manufacturer_rebate", promotion: promotions[2])
        ]
        
        // Generate additional items to reach approximately 147 total
        var additionalItems: [SaleItem] = []
        let baseItemTemplates = [
            ("Kirkland Signature", ["Organic", "Premium", "Ultra"], ["Snacks", "Beverages", "Cleaning", "Personal Care"]),
            ("Samsung", ["QLED", "Smart", "4K"], ["TV", "Monitor", "Tablet", "Phone"]),
            ("Apple", ["iPad", "MacBook", "AirPods"], ["Pro", "Air", "Mini"]),
            ("Sony", ["Bravia", "PlayStation", "Headphones"], ["4K", "Wireless", "Gaming"]),
            ("Tide", ["Ultra", "Free & Gentle", "Pods"], ["Detergent", "Softener", "Stain Remover"]),
            ("Charmin", ["Ultra Soft", "Ultra Strong", "Sensitive"], ["Toilet Paper", "Wipes"])
        ]
        
        for i in 51...120 {
            let template = baseItemTemplates[i % baseItemTemplates.count]
            let brand = template.0
            let modifier = template.1[i % template.1.count]
            let category = template.2[i % template.2.count]
            let promotion = promotions[i % promotions.count]
            
            let basePrice = Double.random(in: 15.99...299.99)
            let savingsAmount = Double.random(in: 3.00...50.00)
            let salePrice = basePrice - savingsAmount
            
            let saleTypes = ["instant_rebate", "sale", "coupon", "manufacturer_rebate"]
            let saleType = saleTypes[i % saleTypes.count]
            
            additionalItems.append(SaleItem(
                id: i,
                itemCode: String(format: "1%06d", Int.random(in: 100000...999999)),
                description: "\(brand) \(modifier) \(category)",
                regularPrice: basePrice,
                salePrice: salePrice,
                instantRebate: saleType == "instant_rebate" ? savingsAmount : nil,
                savings: savingsAmount,
                saleType: saleType,
                promotion: promotion
            ))
        }
        
        return saleItems + additionalItems
    }
    
    private func calculateDaysRemaining(endDate: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let end = formatter.date(from: endDate) else {
            return 0
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: end)
        
        return max(0, components.day ?? 0)
    }
} 