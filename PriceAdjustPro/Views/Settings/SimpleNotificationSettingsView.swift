import SwiftUI
import UserNotifications

struct SimpleNotificationSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var notificationsEnabled = true
    @State private var saleAlertsEnabled = true
    @State private var receiptProcessingAlertsEnabled = true
    @State private var priceDropAlertsEnabled = true
    @State private var permissionStatus = "Unknown"
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                List {
                    // Master toggle
                    Section("Notifications") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Enable Notifications")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Text("Allow PriceAdjustPro to send notifications")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
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
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.costcoRed)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Sale Alerts")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Text("New sales and price drops")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                Spacer()
                                Toggle("", isOn: $saleAlertsEnabled)
                                    .tint(.costcoRed)
                            }
                            
                            // Receipt processing
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.costcoRed)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Receipt Processing")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Text("When receipt processing completes")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                Spacer()
                                Toggle("", isOn: $receiptProcessingAlertsEnabled)
                                    .tint(.costcoRed)
                            }
                            
                            // Price drop alerts
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.costcoRed)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Price Drop Alerts")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Text("When prices drop on items")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                Spacer()
                                Toggle("", isOn: $priceDropAlertsEnabled)
                                    .tint(.costcoRed)
                            }
                        }
                        .listRowBackground(themeManager.cardBackgroundColor)
                    }
                    
                    // Permission status
                    Section("System Settings") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Permission Status")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Text(permissionStatus)
                                    .font(.caption)
                                    .foregroundColor(permissionStatusColor)
                            }
                            
                            Spacer()
                            
                            Button("Check Status") {
                                checkPermissionStatus()
                            }
                            .foregroundColor(.costcoRed)
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // Actions
                    Section("Actions") {
                        Button(action: {
                            sendTestNotification()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundColor(.costcoRed)
                                    .frame(width: 30)
                                Text("Send Test Notification")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                            }
                        }
                        
                        Button(action: {
                            openAppSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.costcoRed)
                                    .frame(width: 30)
                                Text("Open Settings")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                }
                .background(Color.clear)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarItems(
            trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.costcoRed)
        )
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    private var permissionStatusColor: Color {
        switch permissionStatus {
        case let status where status.contains("Authorized"):
            return .green
        case let status where status.contains("Denied"):
            return .red
        default:
            return .orange
        }
    }
    
    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    permissionStatus = "Authorized ✅"
                case .denied:
                    permissionStatus = "Denied ❌"
                case .notDetermined:
                    permissionStatus = "Not Determined ⚠️"
                case .provisional:
                    permissionStatus = "Provisional ⚠️"
                case .ephemeral:
                    permissionStatus = "Ephemeral ⚠️"
                @unknown default:
                    permissionStatus = "Unknown"
                }
            }
        }
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a test notification from PriceAdjustPro!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error.localizedDescription)")
            } else {
                print("✅ Test notification scheduled!")
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SimpleNotificationSettingsView()
        .environmentObject(ThemeManager())
}