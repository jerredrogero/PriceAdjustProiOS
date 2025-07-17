import Foundation
import UserNotifications
import UIKit
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var isNotificationEnabled = true
    @Published var priceAdjustmentAlertsEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Notification categories
    enum NotificationCategory: String, CaseIterable {
        case priceAdjustment = "PRICE_ADJUSTMENT"
        case generalAlert = "GENERAL_ALERT"
        
        var identifier: String { rawValue }
        
        var actions: [UNNotificationAction] {
            switch self {
            case .priceAdjustment:
                return [
                    UNNotificationAction(
                        identifier: "VIEW_ADJUSTMENTS",
                        title: "View Adjustments",
                        options: [.foreground]
                    ),
                    UNNotificationAction(
                        identifier: "CLAIM_REFUND",
                        title: "Claim Refund",
                        options: [.foreground]
                    )
                ]
            case .generalAlert:
                return []
            }
        }
    }
    
    override init() {
        super.init()
        loadSettings()
        setupNotificationCategories()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() {
        AppLogger.logSecurityEvent("Requesting notification permissions")
        
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.logError(error, context: "Notification permission request")
                    return
                }
                
                AppLogger.logDataOperation("Notification permission granted: \(granted)", success: granted)
                self?.updatePermissionStatus()
                
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            AppLogger.logSecurityEvent("Registered for remote notifications")
        }
    }
    
    func updatePermissionStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationPermissionStatus = settings.authorizationStatus
                AppLogger.logDataOperation("Notification permission status: \(settings.authorizationStatus.rawValue)", success: true)
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        isNotificationEnabled = userDefaults.bool(forKey: "notifications_enabled")
        priceAdjustmentAlertsEnabled = userDefaults.bool(forKey: "price_adjustment_alerts_enabled")
        
        // Default to true if first time
        if userDefaults.object(forKey: "notifications_enabled") == nil {
            isNotificationEnabled = true
            priceAdjustmentAlertsEnabled = true
            saveSettings()
        }
    }
    
    func saveSettings() {
        userDefaults.set(isNotificationEnabled, forKey: "notifications_enabled")
        userDefaults.set(priceAdjustmentAlertsEnabled, forKey: "price_adjustment_alerts_enabled")
        AppLogger.logDataOperation("Notification settings saved", success: true)
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        }
        
        notificationCenter.setNotificationCategories(Set(categories))
        AppLogger.logDataOperation("Notification categories configured", success: true)
    }
    
    // MARK: - Local Notification Scheduling
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        timeInterval: TimeInterval = 1,
        identifier: String? = nil
    ) {
        guard isNotificationEnabled else {
            AppLogger.logWarning("Notifications disabled, skipping notification", context: "NotificationManager")
            return
        }
        
        // Check category-specific settings
        switch category {
        case .priceAdjustment where !priceAdjustmentAlertsEnabled:
            return
        default:
            break
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.identifier
        content.userInfo = userInfo
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                AppLogger.logError(error, context: "Local notification scheduling")
            } else {
                AppLogger.logDataOperation("Local notification scheduled: \(title)", success: true)
            }
        }
    }
    
    // MARK: - Specific Notification Types
    
    func sendPriceAdjustmentNotification(count: Int, totalSavings: Double) {
        let title = "💰 Price Adjustments Available!"
        let body = "You have \(count) new price adjustments worth $\(String(format: "%.2f", totalSavings))"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .priceAdjustment,
            userInfo: [
                "type": "price_adjustments",
                "count": count,
                "total_savings": totalSavings
            ]
        )
    }
    
    // MARK: - Notification Management
    
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        AppLogger.logDataOperation("All notifications cleared", success: true)
    }
    
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // MARK: - Demo/Testing Functions
    
    func sendTestNotification() {
        scheduleLocalNotification(
            title: "🧪 Test Notification",
            body: "This is a test notification to verify push notifications are working!",
            category: .generalAlert,
            timeInterval: 2
        )
    }
    
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        AppLogger.logDataOperation("Notification received in foreground", success: true)
        completionHandler([.banner, .sound])
    }
    
    // Handle notification interactions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        AppLogger.logDataOperation("Notification interaction: \(actionIdentifier)", success: true)
        
        // Handle different actions
        switch actionIdentifier {
        case "VIEW_ADJUSTMENTS":
            handleViewAdjustmentsAction(userInfo: userInfo)
        case "CLAIM_REFUND":
            handleClaimRefundAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    
    private func handleViewAdjustmentsAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: View Price Adjustments")
        // Navigate to Price Adjustments tab
        NotificationCenter.default.post(name: .navigateToPriceAdjustments, object: nil)
    }
    
    private func handleClaimRefundAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: Claim Refund")
        // Navigate to Price Adjustments tab for claiming refund
        NotificationCenter.default.post(name: .navigateToPriceAdjustments, object: nil)
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "price_adjustments":
            NotificationCenter.default.post(name: .navigateToPriceAdjustments, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToPriceAdjustments = Notification.Name("navigateToPriceAdjustments")
}