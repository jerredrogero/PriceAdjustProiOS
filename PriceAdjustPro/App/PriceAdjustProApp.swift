import SwiftUI
import UserNotifications

// MARK: - Global Secure Logging Utility
struct AppLogger {
    // MARK: - User Actions
    static func user(_ action: String) {
        #if DEBUG
        print("👤 [\(Date())] User: \(action)")
        #endif
    }
    
    // MARK: - Network Logging
    static func apiCall(_ method: String, to url: String) {
        #if DEBUG
        print("🌐 [\(Date())] Network: \(method) request to: \(url)")
        #endif
    }
    
    static func apiSuccess(_ statusCode: Int, from url: String) {
        #if DEBUG
        print("✅ [\(Date())] Network: HTTP \(statusCode) from: \(url)")
        #endif
    }
    
    static func logResponseData(_ data: Data, from url: String) {
        #if DEBUG
        // Only show first 200 characters to avoid sensitive data exposure
        let redactedData = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read data"
        print("📥 [\(Date())] Network: Response from \(url): \(redactedData)...")
        #endif
    }
    
    static func logRequestBody(_ data: Data) {
        #if DEBUG
        // Only show first 200 characters to avoid sensitive data exposure  
        let redactedData = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read data"
        print("📤 [\(Date())] Network: Request body: \(redactedData)...")
        #endif
    }
    
    static func logSecurityEvent(_ event: String) {
        #if DEBUG
        print("🔐 [\(Date())] Security: \(event)")
        #endif
    }
    
    // MARK: - Data Operations
    static func logDataOperation(_ operation: String, success: Bool) {
        #if DEBUG
        let status = success ? "✅" : "❌"
        print("\(status) [\(Date())] Data: \(operation)")
        #endif
    }
    
    static func logDataCount(_ count: Int, type: String) {
        #if DEBUG
        print("📊 [\(Date())] Data: Loaded \(count) \(type)")
        #endif
    }
    
    // MARK: - Error Logging
    static func logError(_ error: Error, context: String) {
        print("❌ [\(Date())] Error in \(context): \(error.localizedDescription)")
    }
    
    static func logCriticalError(_ error: Error, context: String) {
        print("🚨 [\(Date())] Critical error in \(context): \(error.localizedDescription)")
    }
    
    static func logWarning(_ message: String, context: String) {
        print("⚠️ [\(Date())] Warning in \(context): \(message)")
    }
}

import CoreData
import KeychainAccess
import Combine
import UserNotifications
import UIKit

// MARK: - App Delegate for Quick Actions
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Handle quick action if app was launched from one
        if let shortcutItem = options.shortcutItem {
            handleQuickAction(shortcutItem)
        }
        
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        // Small delay to ensure the app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            switch shortcutItem.type {
            case "com.priceadjustpro.upload":
                NotificationCenter.default.post(name: .navigateToUpload, object: nil)
            case "com.priceadjustpro.receipts":
                NotificationCenter.default.post(name: .navigateToReceipts, object: nil)
            case "com.priceadjustpro.onsale":
                NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
            default:
                break
            }
        }
    }
}

// MARK: - Scene Delegate for Quick Actions
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // Handle quick action when app is already running
        handleQuickAction(shortcutItem)
        completionHandler(true)
    }
    
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "com.priceadjustpro.upload":
            NotificationCenter.default.post(name: .navigateToUpload, object: nil)
        case "com.priceadjustpro.receipts":
            NotificationCenter.default.post(name: .navigateToReceipts, object: nil)
        case "com.priceadjustpro.onsale":
            NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
        default:
            break
        }
    }
}

@main
struct PriceAdjustProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService()
    @StateObject private var receiptStore = ReceiptStore()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var accountService = AccountService.shared
    // @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var priceAdjustmentsViewModel = PriceAdjustmentsViewModel()
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .environmentObject(themeManager)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(authService)
                        .environmentObject(receiptStore)
                        .environmentObject(themeManager)
                        .environmentObject(accountService)
                        // .environmentObject(notificationManager)
                        .environmentObject(priceAdjustmentsViewModel)
                        .environmentObject(storeKitService)
                        .preferredColorScheme(themeManager.colorScheme)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                // Initialize services on app launch
                receiptStore.setPersistenceController(persistenceController)
                setupNotifications()
                setupQuickActions()
                
                // Clear notification badge when app launches
                clearNotificationBadge()
                
                // Hide splash screen after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSplash = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Clear badge when app comes to foreground
                clearNotificationBadge()
            }
            .onReceive(authService.$isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    // Start daily checking when user logs in
                    priceAdjustmentsViewModel.startDailyChecking()
                    // Do an initial check
                    priceAdjustmentsViewModel.checkForPriceAdjustments()
                } else {
                    // Stop daily checking when user logs out
                    priceAdjustmentsViewModel.stopDailyChecking()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .priceAdjustmentFound)) { notification in
                // Handle price adjustment found notification
                if let userInfo = notification.userInfo,
                   let count = userInfo["count"] as? Int,
                   let totalSavings = userInfo["totalSavings"] as? Double {
                    
                    // Send basic notification using UNUserNotificationCenter directly
                    sendPriceAdjustmentNotification(count: count, totalSavings: totalSavings)
                }
            }
            .onOpenURL { url in
                // Handle deep links (e.g., priceadjustpro://upload)
                handleDeepLink(url)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "priceadjustpro" else { return }
        
        // Small delay to ensure app is ready after splash screen
        let delay = showSplash ? 2.5 : 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            switch url.host {
            case "upload":
                NotificationCenter.default.post(name: .navigateToUpload, object: nil)
            case "receipts":
                NotificationCenter.default.post(name: .navigateToReceipts, object: nil)
            case "onsale":
                NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
            case "analytics":
                NotificationCenter.default.post(name: .navigateToPriceAdjustments, object: nil)
            default:
                break
            }
        }
    }
    
    private func setupQuickActions() {
        // Define Quick Actions for home screen long-press menu
        let uploadAction = UIApplicationShortcutItem(
            type: "com.priceadjustpro.upload",
            localizedTitle: "Upload Receipt",
            localizedSubtitle: "Scan a new receipt",
            icon: UIApplicationShortcutIcon(systemImageName: "camera.fill"),
            userInfo: nil
        )
        
        let viewReceiptsAction = UIApplicationShortcutItem(
            type: "com.priceadjustpro.receipts",
            localizedTitle: "View Receipts",
            localizedSubtitle: "See all your receipts",
            icon: UIApplicationShortcutIcon(systemImageName: "doc.text"),
            userInfo: nil
        )
        
        let onSaleAction = UIApplicationShortcutItem(
            type: "com.priceadjustpro.onsale",
            localizedTitle: "On Sale",
            localizedSubtitle: "View current deals",
            icon: UIApplicationShortcutIcon(systemImageName: "tag.fill"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [uploadAction, viewReceiptsAction, onSaleAction]
        AppLogger.logDataOperation("Quick Actions setup complete: \(UIApplication.shared.shortcutItems?.count ?? 0) actions", success: true)
    }
    
    private func setupNotifications() {
        // TODO: Re-enable when notification manager is accessible
        // Update notification permission status
        // notificationManager.updatePermissionStatus()
        
        // Request permissions if not yet determined
        // if notificationManager.notificationPermissionStatus == UNAuthorizationStatus.notDetermined {
        //     notificationManager.requestNotificationPermission()
        // }
        
        AppLogger.logDataOperation("Notification system initialized", success: true)
    }
    
    private func clearNotificationBadge() {
        // Clear the app icon badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Also clear any delivered notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        AppLogger.logDataOperation("Notification badge cleared", success: true)
    }
    
    private func sendPriceAdjustmentNotification(count: Int, totalSavings: Double) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Price Adjustments Available!"
        content.body = "You have \(count) new price adjustments worth $\(String(format: "%.2f", totalSavings))"
        content.badge = 1
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "price-adjustment-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.logError(error, context: "Price adjustment notification")
            } else {
                AppLogger.logDataOperation("Price adjustment notification sent: \(count) adjustments worth $\(String(format: "%.2f", totalSavings))", success: true)
            }
        }
    }
} 