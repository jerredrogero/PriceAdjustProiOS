import SwiftUI
import CoreData
import KeychainAccess
import Combine

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
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
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Clear any old sample/local receipts and sync fresh from server
                receiptStore.clearAllLocalReceipts()
                receiptStore.syncWithServer()
            }
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
                
                // Receipts - view all receipts
                ReceiptListView()
                    .tabItem {
                        Image(systemName: "receipt")
                        Text("Receipts")
                    }
                    .tag(1)
                
                // Upload - add new receipts
                AddReceiptView()
                    .tabItem {
                        Image(systemName: "plus.circle")
                        Text("Upload")
                    }
                    .tag(2)
                
                // Price Adjustments - THE MAIN FEATURE
                PriceAdjustmentsView()
                    .tabItem {
                        Image(systemName: "dollarsign.circle")
                        Text("Adjustments")
                    }
                    .tag(3)
                
                // On Sale - current Costco promotions
                OnSaleView()
                    .tabItem {
                        Image(systemName: "tag")
                        Text("On Sale")
                    }
                    .tag(4)
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