import SwiftUI
import CoreData
import Combine

struct AnalyticsView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimeFrame: TimeFrame = .month
    @State private var showingSettings = false
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Time Frame Picker
                        Picker("Time Frame", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                                Text(timeFrame.rawValue).tag(timeFrame)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        // Time Frame Context
                        if let interval = currentDateInterval {
                            Text("Showing data from \(interval.start, style: .date) to \(interval.end, style: .date)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            Text("Showing all-time data")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                        
                        // Summary Cards
                        HStack {
                            StatCard(
                                title: "Total Spent",
                                value: String(format: "$%.2f", totalSpent),
                                icon: "dollarsign.circle.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "# of Receipts",
                                value: "\(receiptCount)",
                                icon: "doc.fill",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                        
                        // Average Transaction
                        StatCard(
                            title: "Avg Receipt",
                            value: String(format: "$%.2f", averageReceipt),
                            icon: "chart.bar.fill",
                            color: .orange
                        )
                        .padding(.horizontal)
                        
                        // Categories Section
                        VStack(alignment: .leading) {
                            Text("Top Categories")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal)
                            
                            if topCategories.isEmpty {
                                Text("No data available for \(selectedTimeFrame.rawValue.lowercased())")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(Array(topCategories.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { category, amount in
                                            CategoryCard(
                                                category: category,
                                                amount: String(format: "%.2f", amount)
                                            )
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        
                        // Monthly Spending Section (only show if there's data)
                        if !spendingByMonth.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Spending by Month")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(Array(spendingByMonth.sorted { $0.value > $1.value }), id: \.key) { month, amount in
                                            CategoryCard(
                                                category: month,
                                                amount: String(format: "%.2f", amount)
                                            )
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        
                        // Recent Activity
                        VStack(alignment: .leading) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal)
                            
                            let recentReceipts = currentDateInterval == nil ? 
                                Array(receiptStore.receipts.prefix(5)) :
                                Array(receiptStore.receipts.filter { receipt in
                                    currentDateInterval!.contains(receipt.date ?? Date())
                                }.prefix(5))
                            
                            if recentReceipts.isEmpty {
                                Text("No receipts found for \(selectedTimeFrame.rawValue.lowercased())")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(recentReceipts) { receipt in
                                    NavigationLink(destination: DetailViewWrapper(receipt: receipt)) {
                                        RecentActivityRow(receipt: receipt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarItems(
                trailing: Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(themeManager.accentColor)
                }
            )
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.red)
                Text(title)
                    .foregroundColor(.gray)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct CategoryCard: View {
    let category: String
    let amount: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category)
                .font(.headline)
                .foregroundColor(.white)
            
            Text("$\(amount)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 150)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct RecentActivityRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(receipt.storeName ?? "Unknown Store")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(receipt.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "$%.2f", receipt.total))
                .font(.headline)
                .foregroundColor(.white)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(10)
        .shadow(radius: 1)
        .padding(.horizontal)
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(ReceiptStore())
        .environmentObject(ThemeManager())
} 