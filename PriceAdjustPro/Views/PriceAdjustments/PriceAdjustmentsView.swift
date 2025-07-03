import SwiftUI

struct PriceAdjustmentsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = PriceAdjustmentsViewModel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading price adjustments...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.adjustments.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Price Adjustments Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("You're all caught up! We'll notify you when any of your purchased items go on sale.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Total Savings Header
                            if viewModel.totalPotentialSavings > 0 {
                                VStack(spacing: 8) {
                                    Text("Total Potential Savings")
                                        .font(.headline)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    
                                    Text("$\(viewModel.totalPotentialSavings, specifier: "%.2f")")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.successColor)
                                }
                                .padding()
                                .background(themeManager.cardBackgroundColor)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                            }
                            
                            // Price Adjustments List
                            ForEach(viewModel.adjustments) { adjustment in
                                PriceAdjustmentCard(
                                    adjustment: adjustment,
                                    onDismiss: {
                                        viewModel.dismissAdjustment(adjustment.itemCode) { success, message in
                                            alertMessage = message
                                            showingAlert = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Price Adjustments")
            .refreshable {
                viewModel.loadPriceAdjustments()
            }
        }
        .onAppear {
            viewModel.loadPriceAdjustments()
        }
        .alert("Price Adjustment", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct PriceAdjustmentCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let adjustment: PriceAdjustment
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(adjustment.description)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Item: \(adjustment.itemCode)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            
            // Price Information
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You Paid")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("$\(adjustment.currentPrice, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(themeManager.secondaryTextColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Now On Sale")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("$\(adjustment.lowerPrice, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.successColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Potential Refund")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("$\(adjustment.priceDifference, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.successColor)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                    Text(adjustment.storeLocation)
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(themeManager.warningColor)
                    Text("Purchased: \(formatDate(adjustment.purchaseDate))")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(adjustment.daysRemaining <= 3 ? themeManager.errorColor : themeManager.primaryTextColor)
                    Text("\(adjustment.daysRemaining) days remaining")
                        .font(.subheadline)
                        .foregroundColor(adjustment.daysRemaining <= 3 ? themeManager.errorColor : themeManager.primaryTextColor)
                }
                
                // Confidence and action
                HStack {
                    ConfidenceBadge(level: adjustment.confidenceLevel)
                    
                    Spacer()
                    
                    if adjustment.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(themeManager.successColor)
                        Text("Official")
                            .font(.caption)
                            .foregroundColor(themeManager.successColor)
                    }
                }
            }
            
            // Source Description
            Text(adjustment.sourceDescription)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .padding(.top, 4)
            
            // Action Required
            if !adjustment.actionRequired.isEmpty {
                Text(adjustment.actionRequired)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}

struct ConfidenceBadge: View {
    let level: String
    
    var body: some View {
        Text(level.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch level.lowercased() {
        case "high":
            return .green.opacity(0.2)
        case "medium":
            return .orange.opacity(0.2)
        case "low":
            return .red.opacity(0.2)
        default:
            return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch level.lowercased() {
        case "high":
            return .green
        case "medium":
            return .orange
        case "low":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    PriceAdjustmentsView()
        .environmentObject(ThemeManager())
} 