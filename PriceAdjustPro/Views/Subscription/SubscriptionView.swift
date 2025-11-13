import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var accountService: AccountService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if storeKitService.isPremiumUser {
                            premiumUserSection
                        } else {
                            subscriptionOptionsSection
                        }
                        
                        featuresSection
                        
                        legalSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.accentColor)
            )
            .onAppear {
                Task {
                    await storeKitService.loadProducts()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(themeManager.accentColor)
            
            Text("Upgrade to Premium")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("Unlock unlimited receipt uploads and advanced features")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Premium User Section
    
    private var premiumUserSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Premium Active")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
            }
            
            Text("Thank you for being a Premium subscriber! You have access to all features.")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                Task {
                    await storeKitService.restorePurchases()
                }
            }) {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(themeManager.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Subscription Options
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 16) {
            if storeKitService.isLoading {
                ProgressView("Loading subscription options...")
                    .foregroundColor(themeManager.secondaryTextColor)
            } else if storeKitService.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Subscription Setup Required")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    if let errorMessage = storeKitService.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Subscription products need to be configured in App Store Connect before they can be purchased.")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button("Retry") {
                        Task {
                            await storeKitService.loadProducts()
                        }
                    }
                    .foregroundColor(themeManager.accentColor)
                }
                .padding()
            } else {
                ForEach(storeKitService.products, id: \.id) { product in
                    SubscriptionOptionView(
                        product: product,
                        isPopular: product.id.contains("yearly"),
                        themeManager: themeManager
                    ) {
                        await purchaseProduct(product)
                    }
                }
                
                Button("Restore Purchases") {
                    Task {
                        await storeKitService.restorePurchases()
                    }
                }
                .foregroundColor(themeManager.accentColor)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "doc.text.fill",
                    title: "Unlimited Receipt Uploads",
                    description: "Upload as many receipts as you want",
                    themeManager: themeManager
                )
                
                FeatureRow(
                    icon: "chart.bar.fill",
                    title: "Advanced Analytics",
                    description: "Detailed insights into your spending patterns",
                    themeManager: themeManager
                )
                
                FeatureRow(
                    icon: "bell.fill",
                    title: "Priority Notifications",
                    description: "Get notified first about price adjustments",
                    themeManager: themeManager
                )
                
                FeatureRow(
                    icon: "icloud.fill",
                    title: "Cloud Sync",
                    description: "Access your data across all devices",
                    themeManager: themeManager
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("• Payment will be charged to your Apple ID account at confirmation of purchase")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("• Subscription automatically renews unless canceled at least 24 hours before the end of the current period")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("• You can manage and cancel your subscription in your Apple ID account settings")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
    
    // MARK: - Purchase Logic
    
    private func purchaseProduct(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let transaction = try await storeKitService.purchase(product)
            if transaction != nil {
                // Purchase successful
                AppLogger.user("Premium subscription purchased successfully")
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            AppLogger.logError(error, context: "Premium subscription purchase")
        }
        
        isLoading = false
    }
}

// MARK: - Subscription Option View

struct SubscriptionOptionView: View {
    let product: Product
    let isPopular: Bool
    let themeManager: ThemeManager
    let onPurchase: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isPopular {
                HStack {
                    Spacer()
                    Text("MOST POPULAR")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(themeManager.accentColor)
                        .cornerRadius(8)
                    Spacer()
                }
                .offset(y: -8)
            }
            
            VStack(spacing: 8) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(product.displayPrice)
                    .font(.title.weight(.bold))
                    .foregroundColor(themeManager.accentColor)
                
                if product.id.contains("yearly") {
                    Text("Save 20% vs monthly")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Button(action: {
                Task {
                    isLoading = true
                    await onPurchase()
                    isLoading = false
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Processing..." : "Subscribe")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.accentColor)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isPopular ? themeManager.accentColor : themeManager.accentColor.opacity(0.3), lineWidth: isPopular ? 2 : 1)
                )
        )
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(themeManager.accentColor)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(ThemeManager())
        .environmentObject(AccountService.shared)
}
