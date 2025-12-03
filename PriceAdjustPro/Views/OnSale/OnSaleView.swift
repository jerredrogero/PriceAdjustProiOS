import SwiftUI

struct OnSaleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OnSaleViewModel()
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "All"
    @State private var searchTimer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        TextField("Search items...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(10)
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(themeManager.cardBackgroundColor)
                .shadow(radius: 1)
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading current sales...")
                    Spacer()
                } else if viewModel.hasError {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Feature Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("The On Sale feature is being developed and will be available in a future update.")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            viewModel.loadSales()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else if filteredSales.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Sales Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("Try adjusting your search or category filter")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Active Promotions Summary
                            if !viewModel.activePromotions.isEmpty {
                                PromotionsSummaryCard(promotions: viewModel.activePromotions)
                            }
                            
                            // Sales Items
                            ForEach(filteredSales) { item in
                                SaleItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        viewModel.loadSales()
                    }
                }
                }
            }
            .navigationTitle("On Sale")
        }
        .onAppear {
            viewModel.loadSales()
        }
        .onChange(of: searchText) { newValue in
            // Cancel the previous timer
            searchTimer?.invalidate()
            
            // Set a new timer
            searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                debouncedSearchText = newValue
            }
        }
    }
    
    private var filteredSales: [SaleItem] {
        var filtered = viewModel.sales
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { extractCategory(from: $0.description) == selectedCategory }
        }
        
        // Filter by search text (using debounced search)
        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter {
                $0.description.localizedCaseInsensitiveContains(debouncedSearchText) ||
                $0.itemCode.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }
        return filtered
    }
    
    private func extractCategory(from description: String) -> String {
        let desc = description.lowercased()
        
        // Use a scoring system - category with highest score wins
        // This handles items that match multiple categories better
        
        var scores: [String: Int] = [
            "Food & Beverages": 0,
            "Health & Beauty": 0,
            "Baby & Kids": 0,
            "Household & Cleaning": 0,
            "Electronics": 0,
            "Home & Garden": 0,
            "Clothing": 0,
            "Automotive": 0
        ]
        
        // AUTOMOTIVE - Check first with high-confidence keywords
        // These should NOT be confused with other categories
        let automotiveKeywords = [
            "motor oil", "tire", "tires", "automotive", "car care",
            "brake fluid", "transmission", "windshield", "wiper blade",
            "engine oil", "5w-30", "5w-20", "10w-30", "synthetic oil",
            "michelin", "goodyear", "bridgestone", "armor all"
        ]
        if containsAnyKeyword(desc, keywords: automotiveKeywords) {
            scores["Automotive"]! += 100  // High confidence
        }
        
        // ELECTRONICS - High confidence keywords
        let electronicsHighConfidence = [
            "tv", "television", "laptop", "computer", "tablet", "ipad",
            "iphone", "smartphone", "camera", "headphone", "headphones",
            "speaker", "monitor", "printer", "qled", "oled", "4k",
            "macbook", "chromebook", "playstation", "nintendo", "xbox",
            "airpods", "galaxy buds", "wireless earbuds", "soundbar"
        ]
        if containsAnyKeyword(desc, keywords: electronicsHighConfidence) {
            scores["Electronics"]! += 100
        }
        
        // Electronics brand names (medium confidence - could be accessories)
        let electronicsBrands = ["samsung", "sony", "lg", "dell", "hp", "bose", "canon", "nikon"]
        if containsAnyKeyword(desc, keywords: electronicsBrands) {
            // Only boost if not already high confidence for another category
            if !containsAnyKeyword(desc, keywords: ["lotion", "cream", "moisturizer", "cleanser"]) {
                scores["Electronics"]! += 50
            }
        }
        
        // HOME & GARDEN - Kitchen appliances and home items
        // Must check BEFORE food to avoid "blender" matching food
        let homeGardenHighConfidence = [
            "vacuum", "dyson", "shark", "roomba", "blender", "vitamix",
            "ninja blender", "mixer", "kitchenaid", "stand mixer",
            "instant pot", "air fryer", "pressure cooker", "slow cooker",
            "grill", "weber", "traeger", "mattress", "pillow", "sheet set",
            "blanket", "comforter", "towel", "bath towel", "cookware",
            "knife set", "pots and pans", "furniture", "sofa", "chair",
            "table", "lamp", "curtain", "rug", "garden hose", "lawn mower"
        ]
        if containsAnyKeyword(desc, keywords: homeGardenHighConfidence) {
            scores["Home & Garden"]! += 100
        }
        
        // BABY & KIDS - Check before household (both have "wipes")
        let babyKidsHighConfidence = [
            "baby", "infant", "toddler", "diaper", "diapers", "huggies",
            "pampers", "baby wipes", "baby food", "formula", "stroller",
            "car seat", "baby einstein", "toy", "toys", "kids", "children"
        ]
        if containsAnyKeyword(desc, keywords: babyKidsHighConfidence) {
            scores["Baby & Kids"]! += 100
        }
        
        // HOUSEHOLD & CLEANING
        let householdHighConfidence = [
            "detergent", "laundry", "dishwasher pods", "dishwasher pacs",
            "disinfecting wipes", "cleaning wipes", "toilet paper",
            "paper towel", "paper towels", "trash bag", "lysol",
            "tide pods", "tide", "cascade", "charmin", "bounty",
            "clorox", "cleaning", "cleaner", "fabric softener"
        ]
        if containsAnyKeyword(desc, keywords: householdHighConfidence) {
            // Don't classify as household if it's baby wipes
            if !desc.contains("baby") {
                scores["Household & Cleaning"]! += 100
            }
        }
        
        // HEALTH & BEAUTY - Personal care and supplements
        // Be careful not to match food items
        let healthBeautyHighConfidence = [
            "shampoo", "conditioner", "lotion", "moisturizer", "cleanser",
            "soap", "body wash", "deodorant", "antiperspirant", "toothpaste",
            "toothbrush", "electric toothbrush", "oral-b", "sunscreen", "spf",
            "face wash", "skin care", "skincare", "makeup", "cosmetic",
            "perfume", "cologne", "multivitamin", "vitamins", "supplement",
            "fish oil", "omega-3", "probiotic", "calcium", "magnesium",
            "cerave", "neutrogena", "olay", "first aid", "bandage"
        ]
        if containsAnyKeyword(desc, keywords: healthBeautyHighConfidence) {
            // Exclude if it's clearly a kitchen appliance (Vitamix)
            if !desc.contains("vitamix") && !desc.contains("blender") {
                scores["Health & Beauty"]! += 100
            }
        }
        
        // FOOD & BEVERAGES
        // Use specific food keywords, avoid ambiguous ones
        let foodHighConfidence = [
            "chicken", "beef", "pork", "salmon", "fish fillet", "tuna",
            "ground beef", "steak", "bacon", "sausage", "hot dog",
            "bread", "pasta", "rice", "quinoa", "cereal", "oatmeal",
            "milk", "cheese", "yogurt", "butter", "eggs",
            "olive oil", "coconut oil", "avocado oil", "cooking oil",
            "vegetable oil", "canola oil",
            "nuts", "almonds", "cashews", "peanuts", "trail mix", "mixed nuts",
            "coffee", "tea", "juice", "water", "soda", "energy drink",
            "protein bar", "granola bar", "cookie", "cookies", "chocolate",
            "candy", "snack", "chips", "crackers", "popcorn",
            "frozen pizza", "ice cream", "frozen", "fruit", "vegetable",
            "avocado", "berries", "apple", "banana", "orange",
            "almond butter", "peanut butter"
        ]
        if containsAnyKeyword(desc, keywords: foodHighConfidence) {
            scores["Food & Beverages"]! += 100
        }
        
        // Lower confidence food keywords (only if no other strong match)
        let foodMediumConfidence = ["organic", "kirkland signature"]
        if containsAnyKeyword(desc, keywords: foodMediumConfidence) {
            // Only boost food if description seems food-related
            let foodIndicators = ["oz", "lb", "lbs", "count", "pack", "fl oz", "gallon"]
            if containsAnyKeyword(desc, keywords: foodIndicators) {
                // But not if it's clearly another category
                if scores["Health & Beauty"]! < 100 &&
                   scores["Household & Cleaning"]! < 100 &&
                   scores["Home & Garden"]! < 100 {
                    scores["Food & Beverages"]! += 30
                }
            }
        }
        
        // CLOTHING
        let clothingHighConfidence = [
            "shirt", "shirts", "pants", "shorts", "dress", "jacket", "coat",
            "shoes", "socks", "underwear", "bra", "clothing", "apparel",
            "polo", "jeans", "legging", "leggings", "blouse", "sweater",
            "athletic wear", "activewear", "swimwear", "t-shirt", "hoodie",
            "champion", "levi's", "levis", "calvin klein"
        ]
        if containsAnyKeyword(desc, keywords: clothingHighConfidence) {
            scores["Clothing"]! += 100
        }
        
        // Find the category with the highest score
        let bestCategory = scores.max(by: { $0.value < $1.value })
        
        // Only return a category if we have some confidence
        if let best = bestCategory, best.value > 0 {
            return best.key
        }
        
        return "Other"
    }
    
    private func containsAnyKeyword(_ text: String, keywords: [String]) -> Bool {
        return keywords.contains { keyword in
            // For multi-word keywords, just check if they're contained
            if keyword.contains(" ") {
                return text.contains(keyword)
            }
            // For single words, use word boundaries to avoid partial matches
            // But handle edge cases like "tv" properly
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex?.firstMatch(in: text, options: [], range: range) != nil
        }
    }
}

struct CategoryChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? themeManager.accentColor : themeManager.cardBackgroundColor)
                .foregroundColor(isSelected ? .white : themeManager.primaryTextColor)
                .cornerRadius(20)
        }
    }
}

struct PromotionsSummaryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let promotions: [Promotion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(themeManager.warningColor)
                Text("Active Promotions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            ForEach(promotions.prefix(3), id: \.title) { promotion in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(promotion.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        if let count = promotion.itemsCount {
                            Text("\(count) items")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(promotion.daysRemaining) days left")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(promotion.daysRemaining <= 3 ? themeManager.errorColor : themeManager.warningColor)
                        
                        Text(formatEndDate(promotion.saleEndDate))
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                                  }
              }
          }
          .padding()
          .background(themeManager.cardBackgroundColor)
          .cornerRadius(12)
          .shadow(radius: 2)
      }
      
      private func formatEndDate(_ dateString: String) -> String {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyy-MM-dd"
          if let date = formatter.date(from: dateString) {
              formatter.dateStyle = .short
              return "Ends \(formatter.string(from: date))"
          }
          return "Ends \(dateString)"
      }
  }
  
  struct SaleItemCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: SaleItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.description)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Item: \(item.itemCode)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                SaleTypeBadge(saleType: item.saleType)
            }
            
            // Price Information
            HStack {
                if let regularPrice = item.regularPrice {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Regular Price")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text("$\(regularPrice, specifier: "%.2f")")
                            .font(.subheadline)
                            .strikethrough()
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                
                if let salePrice = item.salePrice {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sale Price")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text("$\(salePrice, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.successColor)
                    }
                }
                
                Spacer()
                
                if let savings = item.savings {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("You Save")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text("$\(savings, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.errorColor)
                    }
                }
            }
            
            // Promotion Details
            VStack(alignment: .leading, spacing: 8) {
                Text(item.promotion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.accentColor)
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(item.promotion.daysRemaining <= 3 ? themeManager.errorColor : themeManager.warningColor)
                    
                    Text("\(item.promotion.daysRemaining) days remaining")
                        .font(.subheadline)
                        .foregroundColor(item.promotion.daysRemaining <= 3 ? themeManager.errorColor : themeManager.primaryTextColor)
                    
                    Spacer()
                    
                    Text("Ends \(formatEndDate(item.promotion.saleEndDate))")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
                  }
          .padding()
          .background(themeManager.cardBackgroundColor)
          .cornerRadius(12)
          .shadow(radius: 2)
      }
      
      private func formatEndDate(_ dateString: String) -> String {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyy-MM-dd"
          if let date = formatter.date(from: dateString) {
              formatter.dateStyle = .short
              return formatter.string(from: date)
          }
          return dateString
      }
  }
  
  struct SaleTypeBadge: View {
    let saleType: String
    
    var body: some View {
        Text(getSaleTypeLabel(saleType))
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private func getSaleTypeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "instant_rebate":
            return "Instant Rebate"
        case "coupon":
            return "Coupon"
        case "manufacturer_rebate":
            return "Mfr Rebate"
        case "sale":
            return "Sale"
        default:
            return type.capitalized
        }
    }
    
    private var backgroundColor: Color {
        switch saleType.lowercased() {
        case "instant_rebate":
            return .green
        case "coupon":
            return .costcoRed
        case "manufacturer_rebate":
            return .purple
        case "sale":
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    OnSaleView()
        .environmentObject(ThemeManager())
} 
