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

@main
struct PriceAdjustProApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService()
    @StateObject private var receiptStore = ReceiptStore()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var accountService = AccountService.shared
    // @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var priceAdjustmentsViewModel = PriceAdjustmentsViewModel()
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
                        .preferredColorScheme(themeManager.colorScheme)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                // Initialize services on app launch
                receiptStore.setPersistenceController(persistenceController)
                setupNotifications()
                
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
        }
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