import SwiftUI
import CoreData
import Combine

struct AnalyticsView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimeFrame: TimeFrame = .month
    @State private var analyticsData: AnalyticsResponse?
    @State private var isLoading = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showingSettings = false
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
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
                        .onChange(of: selectedTimeFrame) { _ in
                            loadAnalyticsData()
                        }
                        
                        // Summary Cards
                        if isLoading {
                            ProgressView("Loading analytics...")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            HStack {
                                StatCard(
                                    title: "Total Spent",
                                    value: "$\(analyticsData?.totalSpent ?? "0.00")",
                                    icon: "dollarsign.circle.fill",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "# of Receipts",
                                    value: "\(analyticsData?.totalReceipts ?? 0)",
                                    icon: "doc.fill",
                                    color: .green
                                )
                            }
                            .padding(.horizontal)
                            
                            // Average Transaction
                            StatCard(
                                title: "Avg Receipt",
                                value: "$\(analyticsData?.averageReceiptTotal ?? "0.00")",
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                            .padding(.horizontal)
                        }
                        
                        // Categories Section
                        VStack(alignment: .leading) {
                            Text("Top Categories")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(Array(analyticsData?.spendingByMonth ?? [:]), id: \.key) { month, spending in
                                        CategoryCard(
                                            category: month,
                                            amount: spending.total
                                        )
                                    }
                                }
                                .padding()
                            }
                        }
                        
                        // Recent Activity
                        VStack(alignment: .leading) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal)
                            
                            ForEach(receiptStore.receipts.prefix(5)) { receipt in
                                RecentActivityRow(receipt: receipt)
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
            .onAppear {
                loadAnalyticsData()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
        }
    }
    
    private func loadAnalyticsData() {
        isLoading = true
        
        APIService.shared.getAnalytics()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading analytics: \(error)")
                    }
                },
                receiveValue: { data in
                    analyticsData = data
                }
            )
            .store(in: &cancellables)
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