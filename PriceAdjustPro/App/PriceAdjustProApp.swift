import SwiftUI
import CoreData
import KeychainAccess
import Combine

@main
struct PriceAdjustProApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService()
    @StateObject private var receiptStore = ReceiptStore()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authService)
                .environmentObject(receiptStore)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    // Initialize services on app launch
                    receiptStore.setPersistenceController(persistenceController)
                }
        }
    }
} 