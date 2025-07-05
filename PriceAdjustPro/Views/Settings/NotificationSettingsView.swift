import SwiftUI
import UserNotifications
import UIKit

struct NotificationSettingsView: View {
    // @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var notificationsEnabled = true
    @State private var saleAlertsEnabled = true
    @State private var receiptProcessingAlertsEnabled = true
    @State private var priceDropAlertsEnabled = true
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section {
                        // Overall notification toggle
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.costcoRed)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push Notifications")
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .font(.headline)
                                Text("Receive notifications about sales and receipts")
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $notificationsEnabled)
                                .tint(.costcoRed)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    if notificationsEnabled {
                        Section("Notification Types") {
                            // Sale alerts
                            NotificationSettingRow(
                                icon: "tag.fill",
                                title: "Sale Alerts",
                                description: "New sales and price drops",
                                isEnabled: $saleAlertsEnabled
                            )
                            
                            // Receipt processing
                            NotificationSettingRow(
                                icon: "doc.text.fill",
                                title: "Receipt Processing",
                                description: "When receipt processing completes",
                                isEnabled: $receiptProcessingAlertsEnabled
                            )
                            
                            // Price drop alerts
                            NotificationSettingRow(
                                icon: "arrow.down.circle.fill",
                                title: "Price Drop Alerts",
                                description: "When prices drop on items",
                                isEnabled: $priceDropAlertsEnabled
                            )
                        }
                        .listRowBackground(themeManager.cardBackgroundColor)
                        
                        Section("Permission Status") {
                            HStack {
                                Image(systemName: permissionStatusIcon)
                                    .foregroundColor(permissionStatusColor)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("System Permission")
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .font(.headline)
                                    Text(permissionStatusText)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                // TODO: Re-enable when NotificationManager is available
                                // if notificationManager.notificationPermissionStatus == .denied {
                                    Button("Settings") {
                                        openAppSettings()
                                    }
                                    .foregroundColor(.costcoRed)
                                    .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(themeManager.cardBackgroundColor)
                        
                        Section("Test Notifications") {
                            Button(action: {
                                notificationManager.sendTestNotification()
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("Send Test Notification")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                            
                            Button(action: {
                                OnSaleViewModel().sendTestNotifications()
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.costcoRed)
                                        .frame(width: 24)
                                    
                                    Text("Send Demo Sale Alerts")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(themeManager.cardBackgroundColor)
                        
                        Section {
                            Button(action: {
                                notificationManager.clearAllNotifications()
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Clear All Notifications")
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(themeManager.cardBackgroundColor)
                    }
                }
                .foregroundColor(themeManager.primaryTextColor)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.costcoRed)
                }
            }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            notificationManager.updatePermissionStatus()
        }
        .onChange(of: notificationManager.isNotificationEnabled) { _ in
            notificationManager.saveSettings()
        }
        .onChange(of: notificationManager.saleAlertsEnabled) { _ in
            notificationManager.saveSettings()
        }
        .onChange(of: notificationManager.receiptProcessingAlertsEnabled) { _ in
            notificationManager.saveSettings()
        }
        .onChange(of: notificationManager.priceDropAlertsEnabled) { _ in
            notificationManager.saveSettings()
        }
    }
    
    private var permissionStatusIcon: String {
        switch notificationManager.notificationPermissionStatus {
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .ephemeral:
            return "clock.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch notificationManager.notificationPermissionStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .costcoRed
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusText: String {
        switch notificationManager.notificationPermissionStatus {
        case .authorized:
            return "Notifications are enabled"
        case .denied:
            return "Notifications are disabled in Settings"
        case .notDetermined:
            return "Permission not yet requested"
        case .provisional:
            return "Provisional authorization granted"
        case .ephemeral:
            return "Temporary authorization"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct NotificationSettingRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.costcoRed)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(themeManager.primaryTextColor)
                    .font(.headline)
                Text(description)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .font(.caption)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .tint(.costcoRed)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotificationSettingsView()
        // .environmentObject(NotificationManager.shared)
        .environmentObject(ThemeManager())
}