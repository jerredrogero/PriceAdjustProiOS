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
        
        // Health & Beauty (check first for specific personal care items)
        let healthBeautyKeywords = [
            "shampoo", "conditioner", "lotion", "cream", "moisturizer", "cleanser",
            "soap", "deodorant", "antiperspirant", "toothpaste", "toothbrush",
            "sunscreen", "beauty bar", "face", "skin", "hair", "makeup",
            "cosmetic", "perfume", "cologne", "vitamin", "supplement",
            "probiotic", "omega", "calcium", "magnesium", "zinc", "iron",
            "multivitamin", "health", "wellness", "medicine", "ointment",
            "bandage", "first aid", "pain relief"
        ]
        
        // Baby & Kids (check early to avoid misclassification)
        let babyKidsKeywords = [
            "baby", "infant", "toddler", "kids", "children", "diaper",
            "wipes", "formula", "baby food", "stroller", "car seat",
            "toy", "game", "puzzle", "educational", "learning"
        ]
        
        // Food & Beverages
        let foodBeverageKeywords = [
            "organic", "food", "snack", "meat", "chicken", "beef", "pork",
            "fish", "salmon", "tuna", "bread", "pasta", "rice", "cereal",
            "milk", "cheese", "yogurt", "butter", "oil", "nuts", "trail mix",
            "coffee", "tea", "juice", "water", "soda", "energy drink",
            "protein", "bar", "cookie", "chocolate", "candy", "frozen",
            "pizza", "ice cream", "fruit", "vegetable", "avocado"
        ]
        
        // Household & Cleaning
        let householdCleaningKeywords = [
            "detergent", "laundry", "dishwasher", "cleaning", "cleaner",
            "disinfectant", "wipes", "toilet paper", "paper towel",
            "trash bag", "storage", "bin", "container", "lysol",
            "tide", "cascade", "charmin", "bounty", "scrub"
        ]
        
        // Electronics
        let electronicsKeywords = [
            "tv", "television", "laptop", "computer", "tablet", "ipad",
            "phone", "smartphone", "camera", "headphone", "speaker",
            "monitor", "printer", "electronic", "tech", "digital",
            "smart", "wifi", "bluetooth", "samsung", "apple", "hp",
            "sony", "lg", "dell", "chromebook", "macbook"
        ]
        
        // Home & Garden
        let homeGardenKeywords = [
            "mattress", "pillow", "sheet", "blanket", "towel", "furniture",
            "sofa", "chair", "table", "bed", "lamp", "curtain",
            "vacuum", "appliance", "kitchen", "cookware", "knife",
            "blender", "mixer", "grill", "garden", "plant", "seed",
            "tool", "hardware", "light", "security", "alarm"
        ]
        
        // Clothing
        let clothingKeywords = [
            "shirt", "pants", "shorts", "dress", "jacket", "coat",
            "shoes", "socks", "underwear", "bra", "clothing", "apparel",
            "fashion", "wear", "polo", "jeans", "legging", "blouse",
            "athletic wear", "activewear", "swimwear"
        ]
        
        // Automotive
        let automotiveKeywords = [
            "tire", "tires", "car", "auto", "automotive", "motor oil",
            "brake", "battery", "engine", "vehicle", "truck", "suv"
        ]
        
        // Check categories in priority order (most specific first)
        if containsAnyKeyword(desc, keywords: babyKidsKeywords) {
            return "Baby & Kids"
        } else if containsAnyKeyword(desc, keywords: healthBeautyKeywords) {
            return "Health & Beauty"
        } else if containsAnyKeyword(desc, keywords: foodBeverageKeywords) {
            return "Food & Beverages"
        } else if containsAnyKeyword(desc, keywords: householdCleaningKeywords) {
            return "Household & Cleaning"
        } else if containsAnyKeyword(desc, keywords: electronicsKeywords) {
            return "Electronics"
        } else if containsAnyKeyword(desc, keywords: homeGardenKeywords) {
            return "Home & Garden"
        } else if containsAnyKeyword(desc, keywords: clothingKeywords) {
            return "Clothing"
        } else if containsAnyKeyword(desc, keywords: automotiveKeywords) {
            return "Automotive"
        }
        
        return "Other"
    }
    
    private func containsAnyKeyword(_ text: String, keywords: [String]) -> Bool {
        return keywords.contains { keyword in
            // Use word boundaries to avoid partial matches
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
