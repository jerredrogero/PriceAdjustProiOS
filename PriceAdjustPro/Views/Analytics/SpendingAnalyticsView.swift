import SwiftUI
import Charts

struct SpendingAnalyticsView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimeFrame: TimeFrame = .all
    @State private var selectedChartType: ChartType = .monthly
    @State private var selectedMonthData: (month: String, amount: Double)? = nil
    @State private var selectedWeekData: (week: String, amount: Double)? = nil
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    enum ChartType: String, CaseIterable {
        case monthly = "Monthly"
        case weekly = "Weekly"
        case category = "Category"
    }
    
    // MARK: - Computed Properties
    
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
    
    private var spendingByMonth: [(month: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM" // e.g., "Oct"
        
        // Generate last 6 months in chronological order (oldest to newest)
        var monthlyData: [(date: Date, month: String, amount: Double)] = []
        
        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let monthKey = formatter.string(from: monthDate)
            monthlyData.append((date: monthDate, month: monthKey, amount: 0))
        }
        
        // Filter receipts
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        // Sum spending by month
        for receipt in filteredReceipts {
            guard let receiptDate = receipt.date else { continue }
            let receiptMonth = calendar.component(.month, from: receiptDate)
            let receiptYear = calendar.component(.year, from: receiptDate)
            
            // Find matching month and add amount
            if let index = monthlyData.firstIndex(where: { 
                calendar.component(.month, from: $0.date) == receiptMonth &&
                calendar.component(.year, from: $0.date) == receiptYear
            }) {
                monthlyData[index].amount += receipt.total
            }
        }
        
        // Return in chronological order (oldest to newest, left to right)
        return monthlyData.map { (month: $0.month, amount: $0.amount) }
    }
    
    private var spendingByWeek: [(week: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        
        // Store data with actual dates for proper sorting
        var weeklyData: [(date: Date, amount: Double)] = []
        
        // Get last 12 weeks
        for weekOffset in (0..<12).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let actualWeekStart = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start else { continue }
            weeklyData.append((date: actualWeekStart, amount: 0))
        }
        
        // Filter receipts
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        // Sum spending by week
        for receipt in filteredReceipts {
            guard let date = receipt.date,
                  let receiptWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            
            // Find matching week and add amount
            if let index = weeklyData.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: receiptWeekStart) }) {
                weeklyData[index].amount += receipt.total
            }
        }
        
        // Convert to display format (already in chronological order)
        return weeklyData.map { (week: formatWeekKey($0.date), amount: $0.amount) }
    }
    
    private func formatWeekKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d" // Short format, e.g., "10/15"
        return formatter.string(from: date)
    }
    
    private var categorySpending: [(category: String, amount: Double, percentage: Double)] {
        let categories = receiptStore.getTopCategories(for: currentDateInterval)
        let total = categories.values.reduce(0, +)
        return categories.sorted { $0.value > $1.value }.map { 
            (category: $0.key, amount: $0.value, percentage: total > 0 ? ($0.value / total) * 100 : 0) 
        }
    }
    
    private var mostPurchasedItems: [(name: String, count: Int, totalSpent: Double)] {
        var itemCounts: [String: (count: Int, total: Double)] = [:]
        
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        for receipt in filteredReceipts {
            for item in receipt.lineItemsArray {
                let name = item.name ?? "Unknown"
                let current = itemCounts[name] ?? (count: 0, total: 0)
                itemCounts[name] = (count: current.count + Int(item.quantity), total: current.total + item.price * Double(item.quantity))
            }
        }
        
        return itemCounts
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .map { (name: $0.key, count: $0.value.count, totalSpent: $0.value.total) }
    }
    
    private var storeVisits: [(store: String, visits: Int, totalSpent: Double)] {
        var storeData: [String: (visits: Int, total: Double)] = [:]
        
        let filteredReceipts = receiptStore.receipts.filter { receipt in
            if let period = currentDateInterval {
                return period.contains(receipt.date ?? Date())
            }
            return true
        }
        
        for receipt in filteredReceipts {
            let store = receipt.storeName ?? "Unknown Store"
            let current = storeData[store] ?? (visits: 0, total: 0)
            storeData[store] = (visits: current.visits + 1, total: current.total + receipt.total)
        }
        
        return storeData.sorted { $0.value.visits > $1.value.visits }
            .map { (store: $0.key, visits: $0.value.visits, totalSpent: $0.value.total) }
    }
    
    private var spendingTrend: (current: Double, previous: Double, changePercent: Double) {
        let calendar = Calendar.current
        let now = Date()
        
        // Current month
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return (0, 0, 0)
        }
        let currentInterval = DateInterval(start: currentMonthStart, end: now)
        let currentSpending = receiptStore.getTotalSpending(for: currentInterval)
        
        // Previous month
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
              let previousMonthEnd = calendar.date(byAdding: .day, value: -1, to: currentMonthStart) else {
            return (currentSpending, 0, 0)
        }
        let previousInterval = DateInterval(start: previousMonthStart, end: previousMonthEnd)
        let previousSpending = receiptStore.getTotalSpending(for: previousInterval)
        
        let changePercent = previousSpending > 0 ? ((currentSpending - previousSpending) / previousSpending) * 100 : 0
        
        return (currentSpending, previousSpending, changePercent)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Summary Cards
                    summarySection
                    
                    // Time Frame Picker
                    timeFramePicker
                    
                    // Trend Card
                    trendCard
                    
                    // Chart Type Picker
                    chartTypePicker
                    
                    // Main Chart
                    mainChartSection
                    
                    // Store Visits
                    storeVisitsSection
                    
                    // Most Purchased Items
                    mostPurchasedSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Spending Analytics")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                SummaryStatCard(
                    title: "Total Spent",
                    value: String(format: "$%.2f", totalSpent),
                    icon: "dollarsign.circle.fill",
                    color: .costcoRed
                )
                
                SummaryStatCard(
                    title: "Receipts",
                    value: "\(receiptCount)",
                    icon: "receipt.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                SummaryStatCard(
                    title: "Average",
                    value: String(format: "$%.2f", averageReceipt),
                    icon: "chart.bar.fill",
                    color: .orange
                )
                
                SummaryStatCard(
                    title: "Categories",
                    value: "\(categorySpending.count)",
                    icon: "tag.fill",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Time Frame Picker
    
    private var timeFramePicker: some View {
        Picker("Time Frame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                Text(timeFrame.rawValue).tag(timeFrame)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(themeManager.cardBackgroundColor.opacity(0.3))
        .cornerRadius(10)
    }
    
    // MARK: - Trend Card
    
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor)
                
                Text("Monthly Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text(String(format: "$%.2f", spendingTrend.current))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Month")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text(String(format: "$%.2f", spendingTrend.previous))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Change")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    HStack(spacing: 4) {
                        Image(systemName: spendingTrend.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        
                        Text(String(format: "%.1f%%", abs(spendingTrend.changePercent)))
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(spendingTrend.changePercent >= 0 ? .red : .green)
                }
            }
        }
        .padding(20)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Chart Type Picker
    
    private var chartTypePicker: some View {
        HStack {
            ForEach(ChartType.allCases, id: \.self) { type in
                Button(action: { selectedChartType = type }) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedChartType == type ? themeManager.accentColor : themeManager.cardBackgroundColor)
                        .foregroundColor(selectedChartType == type ? .white : themeManager.primaryTextColor)
                        .cornerRadius(20)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Main Chart Section
    
    @ViewBuilder
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row with tooltip
            HStack {
                Text(chartTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                // Show tooltip for selected data
                if let data = selectedMonthData, selectedChartType == .monthly {
                    HStack(spacing: 6) {
                        Text(data.month)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(format: "$%.2f", data.amount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.costcoRed)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.costcoRed.opacity(0.1))
                    .cornerRadius(8)
                } else if let data = selectedWeekData, selectedChartType == .weekly {
                    HStack(spacing: 6) {
                        Text(data.week)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(format: "$%.2f", data.amount))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.costcoBlue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.costcoBlue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            switch selectedChartType {
            case .monthly:
                monthlyChart
            case .weekly:
                weeklyChart
            case .category:
                categoryChart
            }
        }
        .padding(20)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    private var chartTitle: String {
        switch selectedChartType {
        case .monthly: return "Monthly Spending"
        case .weekly: return "Weekly Spending (Last 12 Weeks)"
        case .category: return "Spending by Category"
        }
    }
    
    @ViewBuilder
    private var monthlyChart: some View {
        if spendingByMonth.isEmpty {
            emptyChartPlaceholder
        } else {
            if #available(iOS 16.0, *) {
                Chart(spendingByMonth, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(selectedMonthData?.month == item.month ? Color.costcoRed : Color.costcoRed.opacity(0.7))
                    .cornerRadius(4)
                    
                    // Show selection indicator
                    if selectedMonthData?.month == item.month {
                        RuleMark(x: .value("Month", item.month))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(Int(amount))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        // Use geometry size as approximation for plot area
                                        let plotWidth = geometry.size.width
                                        let barCount = CGFloat(spendingByMonth.count)
                                        let barWidth = plotWidth / barCount
                                        
                                        // Calculate which bar index was tapped
                                        let index = Int(x / barWidth)
                                        let clampedIndex = max(0, min(index, spendingByMonth.count - 1))
                                        
                                        selectedMonthData = spendingByMonth[clampedIndex]
                                    }
                                    .onEnded { _ in
                                        selectedMonthData = nil
                                    }
                            )
                    }
                }
                .frame(height: 220)
            } else {
                // Fallback for iOS 15
                legacyBarChart(data: spendingByMonth.map { ($0.month, $0.amount) })
            }
        }
    }
    
    @ViewBuilder
    private var weeklyChart: some View {
        if spendingByWeek.isEmpty {
            emptyChartPlaceholder
        } else {
            if #available(iOS 16.0, *) {
                let weekLabels = spendingByWeek.map { $0.week }
                // Only show every 3rd label to prevent overlap
                let visibleLabels = weekLabels.enumerated().compactMap { index, label in
                    index % 3 == 0 ? label : nil
                }
                
                Chart(spendingByWeek, id: \.week) { item in
                    LineMark(
                        x: .value("Week", item.week),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.costcoBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Week", item.week),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.costcoBlue.opacity(0.1).gradient)
                    
                    PointMark(
                        x: .value("Week", item.week),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(selectedWeekData?.week == item.week ? Color.costcoRed : Color.costcoBlue)
                    .symbolSize(selectedWeekData?.week == item.week ? 150 : 50)
                    
                    // Show selection indicator
                    if selectedWeekData?.week == item.week {
                        RuleMark(x: .value("Week", item.week))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: visibleLabels) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        if let week: String = proxy.value(atX: x) {
                                            if let data = spendingByWeek.first(where: { $0.week == week }) {
                                                selectedWeekData = data
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedWeekData = nil
                                    }
                            )
                    }
                }
                .frame(height: 220)
            } else {
                // Fallback for iOS 15
                legacyBarChart(data: spendingByWeek.map { ($0.week, $0.amount) })
            }
        }
    }
    
    @ViewBuilder
    private var categoryChart: some View {
        if categorySpending.isEmpty {
            emptyChartPlaceholder
        } else {
            VStack(spacing: 12) {
                ForEach(categorySpending.prefix(6), id: \.category) { item in
                    CategoryProgressRow(
                        category: item.category,
                        amount: item.amount,
                        percentage: item.percentage,
                        color: categoryColor(for: item.category)
                    )
                }
            }
        }
    }
    
    private var emptyChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
            
            Text("No data available")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func legacyBarChart(data: [(String, Double)]) -> some View {
        let maxValue = data.map { $0.1 }.max() ?? 1
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.0) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.costcoRed)
                            .frame(width: 30, height: CGFloat(item.1 / maxValue) * 150)
                        
                        Text(item.0)
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 40)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 200)
    }
    
    private func categoryColor(for category: String) -> Color {
        let colors: [Color] = [.costcoRed, .costcoBlue, .green, .orange, .purple, .pink]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
    
    // MARK: - Store Visits Section
    
    private var storeVisitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(.costcoRed)
                
                Text("Store Visits")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            if storeVisits.isEmpty {
                Text("No store visits recorded")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.vertical, 20)
            } else {
                ForEach(storeVisits.prefix(5), id: \.store) { store in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.store)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text("\(store.visits) visits")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "$%.2f", store.totalSpent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .padding(.vertical, 8)
                    
                    if store.store != storeVisits.prefix(5).last?.store {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Most Purchased Section
    
    private var mostPurchasedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Most Purchased Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            if mostPurchasedItems.isEmpty {
                Text("No items purchased yet")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.vertical, 20)
            } else {
                ForEach(mostPurchasedItems.prefix(5), id: \.name) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)
                            
                            Text("Purchased \(item.count) times")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "$%.2f", item.totalSpent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.successColor)
                    }
                    .padding(.vertical, 8)
                    
                    if item.name != mostPurchasedItems.prefix(5).last?.name {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - Supporting Views

struct SummaryStatCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct CategoryProgressRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                Text(String(format: "$%.0f", amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 40, alignment: .trailing)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.secondaryTextColor.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    NavigationView {
        SpendingAnalyticsView()
            .environmentObject(ReceiptStore())
            .environmentObject(ThemeManager())
    }
}

