import SwiftUI
import CoreData
import KeychainAccess
import Combine

// MARK: - Temporary notification names (until NotificationManager is added to build target)
extension Notification.Name {
    static let navigateToOnSale = Notification.Name("navigateToOnSale")
    static let navigateToReceipts = Notification.Name("navigateToReceipts")
    static let navigateToReceipt = Notification.Name("navigateToReceipt")
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var accountService: AccountService
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView(selectedTab: $selectedTab)
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            // Clear old receipts and sync fresh from server if user is authenticated
            if authService.isAuthenticated {
                receiptStore.clearAllLocalReceipts()
                receiptStore.syncWithServer()
            }
            
            // Setup notification navigation handlers
            setupNotificationHandlers()
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Clear any old sample/local receipts and sync fresh from server
                receiptStore.clearAllLocalReceipts()
                receiptStore.syncWithServer()
            }
        }
    }
    
    private func setupNotificationHandlers() {
        // Handle navigation to different tabs based on notifications
        NotificationCenter.default.addObserver(
            forName: .navigateToOnSale,
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 1 // On Sale tab
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToReceipts,
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 2 // Receipts tab
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToReceipt,
            object: nil,
            queue: .main
        ) { notification in
            selectedTab = 2 // Receipts tab
            // Additional handling for specific receipt could be added here
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // Dashboard - main overview (combining analytics + recent items)
                AnalyticsView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Dashboard")
                    }
                    .tag(0)
                    .accessibilityLabel("Dashboard")
                    .accessibilityHint("View analytics and recent activity")
                    .accessibilityIdentifier("dashboard-tab")
                
                // Receipts - view all receipts
                ReceiptListView()
                    .tabItem {
                        Image(systemName: "receipt")
                        Text("Receipts")
                    }
                    .tag(1)
                    .accessibilityLabel("Receipts")
                    .accessibilityHint("View all your receipts")
                    .accessibilityIdentifier("receipts-tab")
                
                // Upload - add new receipts
                AddReceiptView()
                    .tabItem {
                        Image(systemName: "plus.circle")
                        Text("Upload")
                    }
                    .tag(2)
                    .accessibilityLabel("Upload Receipt")
                    .accessibilityHint("Add a new receipt")
                    .accessibilityIdentifier("upload-tab")
                
                // Price Adjustments - THE MAIN FEATURE
                PriceAdjustmentsView()
                    .tabItem {
                        Image(systemName: "dollarsign.circle")
                        Text("Adjustments")
                    }
                    .tag(3)
                    .accessibilityLabel("Price Adjustments")
                    .accessibilityHint("View available price adjustments")
                    .accessibilityIdentifier("adjustments-tab")
                
                // On Sale - current Costco promotions
                OnSaleView()
                    .tabItem {
                        Image(systemName: "tag")
                        Text("On Sale")
                    }
                    .tag(4)
                    .accessibilityLabel("On Sale Items")
                    .accessibilityHint("View current Costco promotions")
                    .accessibilityIdentifier("on-sale-tab")
            }
            .accentColor(themeManager.accentColor)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationService())
        .environmentObject(ReceiptStore())
        .environmentObject(ThemeManager())
} 