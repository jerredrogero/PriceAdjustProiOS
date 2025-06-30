import Foundation

struct ReceiptsListResponse: Codable {
    let receipts: [ReceiptResponse]
    let count: Int?
    let priceAdjustmentsCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case receipts
        case count
        case priceAdjustmentsCount = "price_adjustments_count"
    }
}

struct ReceiptResponse: Codable {
    let transactionNumber: String
    let storeLocation: String?  // Made optional to handle null values
    let storeNumber: String?    // Made optional to handle null values
    let transactionDate: String
    let total: String
    let itemsCount: Int?
    let parsedSuccessfully: Bool
    let parseError: String?
    let subtotal: String
    let tax: String
    let instantSavings: String?
    let ebtAmount: String?
    let file: String?
    let items: [LineItemResponse]
    
    enum CodingKeys: String, CodingKey {
        case transactionNumber = "transaction_number"
        case storeLocation = "store_location"
        case storeNumber = "store_number"
        case transactionDate = "transaction_date"
        case total
        case itemsCount = "items_count"
        case parsedSuccessfully = "parsed_successfully"
        case parseError = "parse_error"
        case subtotal
        case tax
        case instantSavings = "instant_savings"
        case ebtAmount = "ebt_amount"
        case file
        case items
    }
    
    // Helper to convert the date string to Date
    var date: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: transactionDate)
    }
}

struct LineItemResponse: Codable {
    let id: Int
    let itemCode: String
    let description: String
    let price: String
    let quantity: Int
    let totalPrice: String
    let isTaxable: Bool
    let onSale: Bool
    let instantSavings: String?
    let originalPrice: String?  // Made optional to handle null values
    let originalTotalPrice: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemCode = "item_code"
        case description
        case price
        case quantity
        case totalPrice = "total_price"
        case isTaxable = "is_taxable"
        case onSale = "on_sale"
        case instantSavings = "instant_savings"
        case originalPrice = "original_price"
        case originalTotalPrice = "original_total_price"
    }
}

struct ReceiptData {
    let storeName: String
    let date: Date?
    let receiptNumber: String
    let subtotal: Double
    let tax: Double
    let total: Double
    let lineItems: [LineItemData]
}

struct LineItemData {
    let name: String
    let price: Double
    let quantity: Int
    let itemCode: String?
    let category: String?
}

// MARK: - Price Adjustments Models

struct PriceAdjustmentsResponse: Codable {
    let adjustments: [PriceAdjustment]
    let totalPotentialSavings: Double
    
    enum CodingKeys: String, CodingKey {
        case adjustments
        case totalPotentialSavings = "total_potential_savings"
    }
}

struct PriceAdjustment: Codable, Identifiable {
    let id = UUID()
    let itemCode: String
    let description: String
    let currentPrice: Double
    let lowerPrice: Double
    let priceDifference: Double
    let storeLocation: String
    let storeNumber: String
    let purchaseDate: String
    let daysRemaining: Int
    let originalStore: String
    let originalStoreNumber: String
    let dataSource: String
    let isOfficial: Bool
    let promotionTitle: String?
    let saleType: String?
    let confidenceLevel: String
    let transactionNumber: String?
    let sourceDescription: String
    let sourceTypeDisplay: String
    let actionRequired: String
    let locationContext: LocationContext
    
    enum CodingKeys: String, CodingKey {
        case itemCode = "item_code"
        case description
        case currentPrice = "current_price"
        case lowerPrice = "lower_price"
        case priceDifference = "price_difference"
        case storeLocation = "store_location"
        case storeNumber = "store_number"
        case purchaseDate = "purchase_date"
        case daysRemaining = "days_remaining"
        case originalStore = "original_store"
        case originalStoreNumber = "original_store_number"
        case dataSource = "data_source"
        case isOfficial = "is_official"
        case promotionTitle = "promotion_title"
        case saleType = "sale_type"
        case confidenceLevel = "confidence_level"
        case transactionNumber = "transaction_number"
        case sourceDescription = "source_description"
        case sourceTypeDisplay = "source_type_display"
        case actionRequired = "action_required"
        case locationContext = "location_context"
    }
}

struct LocationContext: Codable {
    let type: String
    let description: String
    let storeSpecific: Bool
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case storeSpecific = "store_specific"
    }
}

// MARK: - On Sale Models

struct OnSaleResponse: Codable {
    let sales: [SaleItem]
    let totalCount: Int
    let activePromotions: [Promotion]
    let currentDate: String
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case sales
        case totalCount = "total_count"
        case activePromotions = "active_promotions"
        case currentDate = "current_date"
        case lastUpdated = "last_updated"
    }
}

struct SaleItem: Codable, Identifiable {
    let id: Int
    let itemCode: String
    let description: String
    let regularPrice: Double?
    let salePrice: Double?
    let instantRebate: Double?
    let savings: Double?
    let saleType: String
    let promotion: Promotion
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemCode = "item_code"
        case description
        case regularPrice = "regular_price"
        case salePrice = "sale_price"
        case instantRebate = "instant_rebate"
        case savings
        case saleType = "sale_type"
        case promotion
    }
}

struct Promotion: Codable {
    let title: String
    let saleStartDate: String
    let saleEndDate: String
    let daysRemaining: Int
    let itemsCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case title
        case saleStartDate = "sale_start_date"
        case saleEndDate = "sale_end_date"
        case daysRemaining = "days_remaining"
        case itemsCount = "items_count"
    }
}

// MARK: - Analytics Models

struct AnalyticsResponse: Codable {
    let totalSpent: String
    let instantSavings: String
    let totalReceipts: Int
    let totalItems: Int
    let averageReceiptTotal: String
    let spendingByMonth: [String: MonthlySpending]
    
    enum CodingKeys: String, CodingKey {
        case totalSpent = "total_spent"
        case instantSavings = "instant_savings"
        case totalReceipts = "total_receipts"
        case totalItems = "total_items"
        case averageReceiptTotal = "average_receipt_total"
        case spendingByMonth = "spending_by_month"
    }
}

struct MonthlySpending: Codable {
    let total: String
    let count: Int
}

// MARK: - Update Receipt Models

struct UpdateReceiptRequest: Codable {
    let acceptManualEdits: Bool
    let storeLocation: String?
    let transactionDate: String?
    let subtotal: String?
    let tax: String?
    let total: String?
    let notes: String?
    let items: [UpdateLineItemRequest]?
    
    enum CodingKeys: String, CodingKey {
        case acceptManualEdits = "accept_manual_edits"
        case storeLocation = "store_location"
        case transactionDate = "transaction_date"
        case subtotal
        case tax
        case total
        case notes
        case items
    }
}

struct UpdateLineItemRequest: Codable {
    let id: Int?
    let itemCode: String
    let description: String
    let price: String
    let quantity: Int
    let totalPrice: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemCode = "item_code"
        case description
        case price
        case quantity
        case totalPrice = "total_price"
    }
}