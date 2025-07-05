import SwiftUI
import CoreData
import Combine

struct AnalyticsView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimeFrame: TimeFrame = .month
    @State private var showingSettings = false
    @State private var showingUpload = false
    @State private var navigateToAdjustments = false
    @State private var navigateToOnSale = false
    @State private var navigateToReceipts = false
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    // Computed properties for analytics data based on selected time frame
    private var currentDateInterval: DateInterval? {
        receiptStore.dateInterval(for: selectedTimeFrame.rawValue)
    }
    
    private var totalSpent: Double {
        receiptStore.getTotalSpending(for: currentDateInterval)
    }
    
    private var receiptCount: Int {
        receiptStore.getReceiptCount(for: currentDateInterval)
    }
    
    private var averageReceipt: Double {
        receiptStore.getAverageReceiptAmount(for: currentDateInterval)
    }
    
    private var topCategories: [String: Double] {
        receiptStore.getTopCategories(for: currentDateInterval)
    }
    
    private var spendingByMonth: [String: Double] {
        receiptStore.getSpendingByMonth(for: currentDateInterval)
    }
    
    // New computed properties for enhanced analytics
    private var frequentStores: [String: (count: Int, total: Double)] {
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        var storeData: [String: (count: Int, total: Double)] = [:]
        for receipt in filteredReceipts {
            let storeName = receipt.storeName ?? "Unknown Store"
            let current = storeData[storeName] ?? (count: 0, total: 0.0)
            storeData[storeName] = (count: current.count + 1, total: current.total + receipt.total)
        }
        
        return storeData
    }
    
    private var potentialSavings: Double {
        // Estimate potential savings from high-priced items that might have alternatives
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        var potentialSavings = 0.0
        for receipt in filteredReceipts {
            for item in receipt.lineItemsArray {
                // Items over $50 might have better alternatives or bulk discounts
                if item.price > 50.0 {
                    potentialSavings += item.price * 0.15 // Estimate 15% potential savings
                }
            }
        }
        return potentialSavings
    }
    
    private var weeklyTrend: String {
        let calendar = Calendar.current
        let now = Date()
        
        // Get this week's spending
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return "No trend data" }
        let thisWeekInterval = DateInterval(start: thisWeekStart, end: now)
        let thisWeekSpending = receiptStore.getTotalSpending(for: thisWeekInterval)
        
        // Get last week's spending
        guard let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
              let lastWeekEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart) else { return "No trend data" }
        let lastWeekInterval = DateInterval(start: lastWeekStart, end: lastWeekEnd)
        let lastWeekSpending = receiptStore.getTotalSpending(for: lastWeekInterval)
        
        if lastWeekSpending == 0 { return "No previous data" }
        
        let change = ((thisWeekSpending - lastWeekSpending) / lastWeekSpending) * 100
        if abs(change) < 5 {
            return "Stable"
        } else if change > 0 {
            return "+\(String(format: "%.0f", change))%"
        } else {
            return "\(String(format: "%.0f", change))%"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.backgroundColor,
                        themeManager.backgroundColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Header with greeting and quick stats
                        headerSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Time Frame Picker
                        timeFrameSection
                        
                        // Main Analytics Cards
                        analyticsCardsSection
                        
                        // Enhanced Insights
                        insightsSection
                        
                        // Price Adjustment Opportunities
                        priceAdjustmentSection
                        
                        // Categories and Trends
                        categoriesSection
                        
                        // Recent Activity with enhanced display
                        recentActivitySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(themeManager.accentColor)
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
            // Hidden NavigationLinks for "View All" buttons
            .background(
                Group {
                    NavigationLink(destination: ReceiptListView(), isActive: $navigateToReceipts) { EmptyView() }
                    NavigationLink(destination: PriceAdjustmentsView(), isActive: $navigateToAdjustments) { EmptyView() }
                    NavigationLink(destination: OnSaleView(), isActive: $navigateToOnSale) { EmptyView() }
                }
            )
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(getTimeOfDay())!")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Here's your spending overview")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                // Quick total badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(String(format: "$%.0f", totalSpent))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.horizontal, 4)
            
                         HStack(spacing: 16) {
                 NavigationLink(destination: AddReceiptView(), isActive: $showingUpload) {
                     QuickActionCard(
                         title: "Upload Receipt",
                         icon: "plus.circle.fill",
                         color: .green,
                         action: { showingUpload = true }
                     )
                 }
                 
                 NavigationLink(destination: PriceAdjustmentsView(), isActive: $navigateToAdjustments) {
                     QuickActionCard(
                         title: "Price Adjustments",
                         icon: "dollarsign.circle.fill",
                         color: .costcoRed,
                         action: { navigateToAdjustments = true }
                     )
                 }
                 
                 NavigationLink(destination: OnSaleView(), isActive: $navigateToOnSale) {
                     QuickActionCard(
                         title: "On Sale Items",
                         icon: "tag.fill",
                         color: .orange,
                         action: { navigateToOnSale = true }
                     )
                 }
             }
        }
    }
    
    // MARK: - Time Frame Section
    private var timeFrameSection: some View {
        VStack(spacing: 12) {
            Picker("Time Frame", selection: $selectedTimeFrame) {
                ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                    Text(timeFrame.rawValue).tag(timeFrame)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(themeManager.cardBackgroundColor.opacity(0.3))
            .cornerRadius(10)
            
            if let interval = currentDateInterval {
                Text("Showing data from \(interval.start, style: .date) to \(interval.end, style: .date)")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            } else {
                Text("Showing all-time data")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
    }
    
    // MARK: - Analytics Cards Section
    private var analyticsCardsSection: some View {
        VStack(spacing: 16) {
            // Main stats row
            HStack(spacing: 16) {
                ModernStatCard(
                    title: "Total Spent",
                    value: String(format: "$%.2f", totalSpent),
                    icon: "dollarsign.circle.fill",
                    gradient: [.costcoRed, .costcoRed.opacity(0.7)],
                    subtitle: weeklyTrend
                )
                
                ModernStatCard(
                    title: "Receipts",
                    value: "\(receiptCount)",
                    icon: "receipt.fill",
                    gradient: [.green, .green.opacity(0.7)],
                    subtitle: receiptCount > 0 ? "Tracked" : "None yet"
                )
            }
            
            // Average and potential savings row
            HStack(spacing: 16) {
                ModernStatCard(
                    title: "Avg Receipt",
                    value: String(format: "$%.2f", averageReceipt),
                    icon: "chart.bar.fill",
                    gradient: [.orange, .orange.opacity(0.7)],
                    subtitle: "Per visit"
                )
                
                ModernStatCard(
                    title: "Potential Savings",
                    value: String(format: "$%.0f", potentialSavings),
                    icon: "arrow.down.circle.fill",
                    gradient: [.purple, .purple.opacity(0.7)],
                    subtitle: "Available"
                )
            }
        }
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.horizontal, 4)
            
            if frequentStores.isEmpty && topCategories.isEmpty {
                EmptyInsightsCard()
            } else {
                VStack(spacing: 12) {
                    // Top store insight
                    if let topStore = frequentStores.max(by: { $0.value.total < $1.value.total }) {
                        InsightCard(
                            icon: "building.2.fill",
                            title: "Most Shopped Store",
                            value: topStore.key,
                            subtitle: "\(topStore.value.count) visits • $\(String(format: "%.0f", topStore.value.total))",
                            color: .costcoRed
                        )
                    }
                    
                    // Top category insight
                    if let topCategory = topCategories.max(by: { $0.value < $1.value }) {
                        InsightCard(
                            icon: "tag.fill",
                            title: "Top Spending Category",
                            value: topCategory.key,
                            subtitle: "$\(String(format: "%.0f", topCategory.value)) spent",
                            color: .green
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Price Adjustment Section
    private var priceAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Adjustment Opportunities")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                                 Button("View All") {
                     navigateToAdjustments = true
                 }
                .font(.subheadline)
                .foregroundColor(themeManager.accentColor)
            }
            .padding(.horizontal, 4)
            
            PriceAdjustmentOpportunityCard(
                potentialSavings: potentialSavings,
                recentPurchases: receiptCount,
                onCheckAdjustments: { navigateToAdjustments = true }
            )
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.horizontal, 4)
            
            if topCategories.isEmpty {
                EmptyCategoriesCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(topCategories.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { category, amount in
                            ModernCategoryCard(
                                category: category,
                                amount: amount,
                                percentage: (amount / totalSpent) * 100
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                                 Button("View All") {
                     navigateToReceipts = true
                 }
                .font(.subheadline)
                .foregroundColor(themeManager.accentColor)
            }
            .padding(.horizontal, 4)
            
            let recentReceipts = Array(receiptStore.receipts.prefix(3))
            
            if recentReceipts.isEmpty {
                EmptyActivityCard()
            } else {
                VStack(spacing: 12) {
                    ForEach(recentReceipts) { receipt in
                        NavigationLink(destination: DetailViewWrapper(receipt: receipt)) {
                            ModernActivityRow(receipt: receipt)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
    
    @MainActor
    private func refreshData() async {
        receiptStore.syncWithServer()
        // Add a small delay to show the refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

// MARK: - Modern Stat Card
struct ModernStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Modern Category Card
struct ModernCategoryCard: View {
    let category: String
    let amount: Double
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Text("$\(String(format: "%.0f", amount))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.costcoRed)
                                .frame(width: geometry.size.width * (percentage / 100))
                            Spacer(minLength: 0)
                        }
                    )
            }
            .frame(height: 4)
        }
        .padding(16)
        .frame(width: 160)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Modern Activity Row
struct ModernActivityRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 16) {
            // Store icon
            Image(systemName: "building.2.fill")
                .font(.title3)
                .foregroundColor(.costcoRed)
                .frame(width: 40, height: 40)
                .background(Color.costcoRed.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName ?? "Unknown Store")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(receipt.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", receipt.total))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(receipt.lineItemsArray.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Price Adjustment Opportunity Card
struct PriceAdjustmentOpportunityCard: View {
    let potentialSavings: Double
    let recentPurchases: Int
    let onCheckAdjustments: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential Savings Available")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Based on your recent purchases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if potentialSavings > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("$\(String(format: "%.0f", potentialSavings))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Estimated savings from price adjustments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                                                             Button("Check Adjustments") {
                        onCheckAdjustments()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Text("No adjustment opportunities found yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Empty State Cards
struct EmptyInsightsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No insights yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Upload some receipts to see your spending insights")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct EmptyCategoriesCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No categories yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Your spending categories will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct EmptyActivityCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "receipt")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No recent activity")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Upload your first receipt to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}



#Preview {
    AnalyticsView()
        .environmentObject(ReceiptStore())
        .environmentObject(ThemeManager())
} 