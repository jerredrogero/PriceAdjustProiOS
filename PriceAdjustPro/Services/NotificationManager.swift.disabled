import Foundation
import UserNotifications
import UIKit
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var isNotificationEnabled = true
    @Published var saleAlertsEnabled = true
    @Published var receiptProcessingAlertsEnabled = true
    @Published var priceDropAlertsEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Notification categories
    enum NotificationCategory: String, CaseIterable {
        case saleAlert = "SALE_ALERT"
        case receiptProcessing = "RECEIPT_PROCESSING"
        case priceDropAlert = "PRICE_DROP_ALERT"
        case generalAlert = "GENERAL_ALERT"
        
        var identifier: String { rawValue }
        
        var actions: [UNNotificationAction] {
            switch self {
            case .saleAlert:
                return [
                    UNNotificationAction(
                        identifier: "VIEW_SALE",
                        title: "View Sale",
                        options: [.foreground]
                    ),
                    UNNotificationAction(
                        identifier: "DISMISS",
                        title: "Dismiss",
                        options: []
                    )
                ]
            case .receiptProcessing:
                return [
                    UNNotificationAction(
                        identifier: "VIEW_RECEIPT",
                        title: "View Receipt",
                        options: [.foreground]
                    )
                ]
            case .priceDropAlert:
                return [
                    UNNotificationAction(
                        identifier: "VIEW_ITEM",
                        title: "View Item",
                        options: [.foreground]
                    ),
                    UNNotificationAction(
                        identifier: "ADD_TO_LIST",
                        title: "Add to Shopping List",
                        options: []
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
        saleAlertsEnabled = userDefaults.bool(forKey: "sale_alerts_enabled") 
        receiptProcessingAlertsEnabled = userDefaults.bool(forKey: "receipt_processing_alerts_enabled")
        priceDropAlertsEnabled = userDefaults.bool(forKey: "price_drop_alerts_enabled")
        
        // Default to true if first time
        if userDefaults.object(forKey: "notifications_enabled") == nil {
            isNotificationEnabled = true
            saleAlertsEnabled = true
            receiptProcessingAlertsEnabled = true
            priceDropAlertsEnabled = true
            saveSettings()
        }
    }
    
    func saveSettings() {
        userDefaults.set(isNotificationEnabled, forKey: "notifications_enabled")
        userDefaults.set(saleAlertsEnabled, forKey: "sale_alerts_enabled")
        userDefaults.set(receiptProcessingAlertsEnabled, forKey: "receipt_processing_alerts_enabled")
        userDefaults.set(priceDropAlertsEnabled, forKey: "price_drop_alerts_enabled")
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
        case .saleAlert where !saleAlertsEnabled:
            return
        case .receiptProcessing where !receiptProcessingAlertsEnabled:
            return
        case .priceDropAlert where !priceDropAlertsEnabled:
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
    
    func sendSaleAlert(itemName: String, savings: Double, saleType: String) {
        let title = "🏷️ New Sale Alert!"
        let body = "Save $\(String(format: "%.2f", savings)) on \(itemName) with \(saleType)"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .saleAlert,
            userInfo: [
                "type": "sale_alert",
                "item_name": itemName,
                "savings": savings,
                "sale_type": saleType
            ]
        )
    }
    
    func sendReceiptProcessingComplete(receiptNumber: String, itemCount: Int) {
        let title = "✅ Receipt Processed!"
        let body = "Receipt #\(receiptNumber) processed with \(itemCount) items"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .receiptProcessing,
            userInfo: [
                "type": "receipt_processing",
                "receipt_number": receiptNumber,
                "item_count": itemCount
            ]
        )
    }
    
    func sendPriceDropAlert(itemName: String, oldPrice: Double, newPrice: Double) {
        let savings = oldPrice - newPrice
        let title = "📉 Price Drop Alert!"
        let body = "\(itemName) dropped $\(String(format: "%.2f", savings)) to $\(String(format: "%.2f", newPrice))"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .priceDropAlert,
            userInfo: [
                "type": "price_drop",
                "item_name": itemName,
                "old_price": oldPrice,
                "new_price": newPrice
            ]
        )
    }
    
    func sendNewSalesAvailable(count: Int) {
        let title = "🛍️ New Sales Available!"
        let body = "\(count) new items on sale at Costco!"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .saleAlert,
            userInfo: [
                "type": "new_sales",
                "count": count
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
    
    func sendDemoSaleAlert() {
        sendSaleAlert(
            itemName: "Kirkland Signature Organic Coconut Oil",
            savings: 5.00,
            saleType: "Instant Rebate"
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
        case "VIEW_SALE":
            handleViewSaleAction(userInfo: userInfo)
        case "VIEW_RECEIPT":
            handleViewReceiptAction(userInfo: userInfo)
        case "VIEW_ITEM":
            handleViewItemAction(userInfo: userInfo)
        case "ADD_TO_LIST":
            handleAddToListAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    
    private func handleViewSaleAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: View Sale")
        // Navigate to On Sale tab
        NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
    }
    
    private func handleViewReceiptAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: View Receipt")
        // Navigate to specific receipt if receipt number provided
        if let receiptNumber = userInfo["receipt_number"] as? String {
            NotificationCenter.default.post(
                name: .navigateToReceipt,
                object: nil,
                userInfo: ["receipt_number": receiptNumber]
            )
        } else {
            NotificationCenter.default.post(name: .navigateToReceipts, object: nil)
        }
    }
    
    private func handleViewItemAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: View Item")
        // Navigate to On Sale tab to view specific item
        NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
    }
    
    private func handleAddToListAction(userInfo: [AnyHashable: Any]) {
        AppLogger.user("Notification action: Add to Shopping List")
        // Future: Add to shopping list functionality
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "sale_alert", "new_sales":
            NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
        case "receipt_processing":
            NotificationCenter.default.post(name: .navigateToReceipts, object: nil)
        case "price_drop":
            NotificationCenter.default.post(name: .navigateToOnSale, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToOnSale = Notification.Name("navigateToOnSale")
    static let navigateToReceipts = Notification.Name("navigateToReceipts")
    static let navigateToReceipt = Notification.Name("navigateToReceipt")
}