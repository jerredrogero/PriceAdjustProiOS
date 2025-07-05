import SwiftUI
import UserNotifications

struct DeveloperTestingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    // @EnvironmentObject var notificationManager: NotificationManager
    @State private var selectedDelay: Double = 5.0
    @State private var testTitle = "Test Notification"
    @State private var testBody = "This is a test notification to verify the system is working correctly."
    @State private var notificationStatus = "Unknown"
    @State private var showingResults = false
    @State private var lastTestResult = ""
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notification Testing")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("Test different types of notifications and verify they work correctly.")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Permission Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permission Status")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        HStack {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                            Text(notificationStatus)
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Button("Check Status") {
                                checkNotificationStatus()
                            }
                            .foregroundColor(themeManager.accentColor)
                        }
                        .padding()
                        .background(themeManager.cardBackgroundColor)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Custom Notification Test
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Notification")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        VStack(spacing: 12) {
                            TextField("Notification Title", text: $testTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Notification Body", text: $testBody, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                            
                            HStack {
                                Text("Delay: \(Int(selectedDelay))s")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Slider(value: $selectedDelay, in: 1...30, step: 1)
                                    .accentColor(themeManager.accentColor)
                            }
                            
                            Button(action: {
                                sendCustomNotification()
                            }) {
                                Text("Send Custom Notification")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(themeManager.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackgroundColor)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Predefined Tests
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Predefined Tests")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            
                            TestButton(
                                title: "Sale Alert",
                                icon: "tag.fill",
                                color: .costcoRed
                            ) {
                                sendSaleTestNotification()
                            }
                            
                            TestButton(
                                title: "Price Drop",
                                icon: "arrow.down.circle.fill",
                                color: .green
                            ) {
                                sendPriceDropTestNotification()
                            }
                            
                            TestButton(
                                title: "Receipt Done",
                                icon: "doc.badge.plus",
                                color: .orange
                            ) {
                                sendReceiptTestNotification()
                            }
                            
                            TestButton(
                                title: "New Sales",
                                icon: "bell.badge",
                                color: .purple
                            ) {
                                sendNewSalesTestNotification()
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackgroundColor)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Testing Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Testing Instructions")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionRow(
                                step: "1",
                                text: "Ensure notifications are enabled in Settings"
                            )
                            InstructionRow(
                                step: "2", 
                                text: "Test on a real device (notifications don't work in simulator)"
                            )
                            InstructionRow(
                                step: "3",
                                text: "Put app in background or lock screen to see notifications"
                            )
                            InstructionRow(
                                step: "4",
                                text: "Tap notifications to test navigation"
                            )
                        }
                        .padding()
                        .background(themeManager.cardBackgroundColor)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Test Results
                    if showingResults {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last Test Result")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text(lastTestResult)
                                .font(.body)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .padding()
                                .background(themeManager.cardBackgroundColor)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Notification Testing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationStatus()
        }
    }
    
    private var statusIcon: String {
        switch notificationStatus {
        case let status where status.contains("Authorized"):
            return "checkmark.circle.fill"
        case let status where status.contains("Denied"):
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch notificationStatus {
        case let status where status.contains("Authorized"):
            return .green
        case let status where status.contains("Denied"):
            return .red
        default:
            return .orange
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    notificationStatus = "Authorized ✅"
                case .denied:
                    notificationStatus = "Denied ❌"
                case .notDetermined:
                    notificationStatus = "Not Determined ⚠️"
                case .provisional:
                    notificationStatus = "Provisional ⚠️"
                case .ephemeral:
                    notificationStatus = "Ephemeral ⚠️"
                @unknown default:
                    notificationStatus = "Unknown"
                }
            }
        }
    }
    
    private func sendCustomNotification() {
        let content = UNMutableNotificationContent()
        content.title = testTitle
        content.body = testBody
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: selectedDelay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    lastTestResult = "❌ Failed: \(error.localizedDescription)"
                } else {
                    lastTestResult = "✅ Custom notification scheduled for \(Int(selectedDelay)) seconds"
                }
                showingResults = true
            }
        }
    }
    
    private func sendSaleTestNotification() {
        sendTestNotification(
            title: "🏷️ New Sale Alert!",
            body: "Save $5.00 on Kirkland Signature Organic Coconut Oil with Instant Rebate",
            identifier: "test-sale"
        )
    }
    
    private func sendPriceDropTestNotification() {
        sendTestNotification(
            title: "📉 Price Drop Alert!",
            body: "Kirkland Signature Organic Coconut Oil dropped $5.00 to $19.99",
            identifier: "test-price-drop"
        )
    }
    
    private func sendReceiptTestNotification() {
        sendTestNotification(
            title: "✅ Receipt Processed!",
            body: "Receipt #TEST123456 processed with 15 items",
            identifier: "test-receipt"
        )
    }
    
    private func sendNewSalesTestNotification() {
        sendTestNotification(
            title: "🛍️ New Sales Available!",
            body: "25 new items on sale at Costco!",
            identifier: "test-new-sales"
        )
    }
    
    private func sendTestNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    lastTestResult = "❌ Failed: \(error.localizedDescription)"
                } else {
                    lastTestResult = "✅ \(title) scheduled"
                }
                showingResults = true
            }
        }
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(10)
        }
    }
}

struct InstructionRow: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.red)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

#Preview {
    DeveloperTestingView()
        .environmentObject(ThemeManager())
}