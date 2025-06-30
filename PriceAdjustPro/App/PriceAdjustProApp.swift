import SwiftUI

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
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authService)
                .environmentObject(receiptStore)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    // Initialize services on app launch
                    receiptStore.setPersistenceController(persistenceController)
                    setupNotifications()
                }
        }
    }
    
    private func setupNotifications() {
        // Update notification permission status
        notificationManager.updatePermissionStatus()
        
        // Request permissions if not yet determined
        if notificationManager.notificationPermissionStatus == .notDetermined {
            notificationManager.requestNotificationPermission()
        }
        
        AppLogger.logDataOperation("Notification system initialized", success: true)
    }
} 