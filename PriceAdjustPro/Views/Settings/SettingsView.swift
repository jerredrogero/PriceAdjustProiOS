import SwiftUI
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingLogoutAlert = false
    @State private var showingNotificationSettings = false
    @State private var showingBiometricSetup = false
    @State private var biometricSetupEmail = ""
    @State private var biometricSetupPassword = ""
    @State private var pendingBiometricToggle = false
    @State private var showingPasswordPrompt = false
    @State private var enteredPassword = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                List {
                    // User Profile Section
                    Section {
                        if let user = authService.currentUser {
                            VStack(alignment: .center, spacing: 15) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(themeManager.accentColor)
                                
                                Text(displayName(for: user))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                
                                Text("Member")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // Theme Settings
                    Section(header: Text("Appearance")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        HStack {
                            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(themeManager.accentColor)
                                .frame(width: 25)
                            
                            Text("Dark Mode")
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { themeManager.isDarkMode },
                                set: { _ in themeManager.toggleTheme() }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // Account Settings
                    Section(header: Text("Account Settings")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        Button(action: {
                            showingEditProfile = true
                        }) {
                            SettingsRow(
                                icon: "person.fill",
                                title: "Edit Profile",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            showingChangePassword = true
                        }) {
                            SettingsRow(
                                icon: "lock.fill",
                                title: "Change Password",
                                themeManager: themeManager
                            )
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // App Settings
                    Section(header: Text("App Settings")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        Button(action: {
                            showingNotificationSettings = true
                        }) {
                            SettingsRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                themeManager: themeManager
                            )
                        }
                        
                        // Biometric Authentication Toggle
                        if biometricService.isBiometricAvailable {
                            HStack {
                                Image(systemName: biometricIconName)
                                    .foregroundColor(themeManager.accentColor)
                                    .frame(width: 25)
                                
                                Text(biometricService.biometricTypeString)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { biometricService.isBiometricEnabled },
                                    set: { enabled in
                                        if enabled {
                                            // Don't update state immediately - just trigger the alert
                                            pendingBiometricToggle = true
                                        } else {
                                            // For disabling, do it async to avoid publishing warnings
                                            DispatchQueue.main.async {
                                                biometricService.setBiometricEnabled(false)
                                            }
                                        }
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                            }
                        }
                        
                        NavigationLink(destination: DataManagementView()) {
                            SettingsRow(
                                icon: "externaldrive.fill",
                                title: "Data Management",
                                themeManager: themeManager
                            )
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // Support
                    Section(header: Text("Support")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        Link(destination: URL(string: "https://priceadjustpro.onrender.com/help")!) {
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Help Center",
                                themeManager: themeManager
                            )
                        }
                        
                        Link(destination: URL(string: "https://priceadjustpro.onrender.com/privacy")!) {
                            SettingsRow(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy",
                                themeManager: themeManager
                            )
                        }
                        
                        Link(destination: URL(string: "https://priceadjustpro.onrender.com/terms")!) {
                            SettingsRow(
                                icon: "doc.text.fill",
                                title: "Terms of Service",
                                themeManager: themeManager
                            )
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // App Info
                    Section(header: Text("About")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(themeManager.accentColor)
                                .frame(width: 25)
                            Text("Version")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    // Developer Testing (Only show in Debug builds)
                    #if DEBUG
                    Section(header: Text("Developer Testing")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        
                        Button(action: {
                            sendTestNotification()
                        }) {
                            SettingsRow(
                                icon: "bell.badge",
                                title: "Test Basic Notification",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            sendTestSaleNotification()
                        }) {
                            SettingsRow(
                                icon: "tag.fill",
                                title: "Test Sale Alert",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            sendTestPriceDropNotification()
                        }) {
                            SettingsRow(
                                icon: "arrow.down.circle.fill",
                                title: "Test Price Drop Alert",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            sendTestReceiptNotification()
                        }) {
                            SettingsRow(
                                icon: "doc.badge.plus",
                                title: "Test Receipt Processed",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            sendAdvancedTestNotification()
                        }) {
                            SettingsRow(
                                icon: "hammer.fill",
                                title: "Advanced Testing",
                                themeManager: themeManager
                            )
                        }
                        
                        Button(action: {
                            checkNotificationPermissions()
                        }) {
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Check Permissions",
                                themeManager: themeManager
                            )
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    #endif
                    
                    // Logout
                    Section {
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Log Out")
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                }
                .background(Color.clear)
                .onAppear {
                    // Configure list appearance for theme
                    UITableView.appearance().backgroundColor = UIColor.clear
                    UITableView.appearance().separatorColor = UIColor.clear
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingNotificationSettings) {
                Text("Notification Settings")
                    .font(.title)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.backgroundColor)
            }
            .onChange(of: pendingBiometricToggle) { pending in
                if pending {
                    showingPasswordPrompt = true
                    pendingBiometricToggle = false
                }
            }
            .alert("Enter Your Password", isPresented: $showingPasswordPrompt) {
                SecureField("Password", text: $enteredPassword)
                Button("Cancel", role: .cancel) { 
                    enteredPassword = ""
                }
                Button("Enable") {
                    Task {
                        await enableBiometricAuthFromSettings()
                    }
                }
            } message: {
                Text("Enter your account password to enable \(biometricService.biometricTypeString) for quick login.")
            }
        }
    }
    
    private func displayName(for user: APIUserResponse) -> String {
        if let firstName = user.firstName, let lastName = user.lastName,
           !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if let firstName = user.firstName, !firstName.isEmpty {
            return firstName
        } else if let lastName = user.lastName, !lastName.isEmpty {
            return lastName
        } else if let username = user.username, !username.isEmpty {
            return username
        } else {
            return "User"
        }
    }
    
    // MARK: - Testing Methods
    
    #if DEBUG
    private func sendTestNotification() {
        // First request permission, then send notification
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.scheduleTestNotification(
                        title: "🧪 Test Notification",
                        body: "This is a test notification from PriceAdjustPro!",
                        delay: 2
                    )
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
        
        AppLogger.logDataOperation("Test notification triggered", success: true)
        print("🧪 Test notification sent!")
    }
    
    private func sendTestSaleNotification() {
        scheduleTestNotification(
            title: "🏷️ New Sale Alert!",
            body: "Save $5.00 on Kirkland Signature Organic Coconut Oil with Instant Rebate",
            delay: 2
        )
        AppLogger.logDataOperation("Test sale notification triggered", success: true)
        print("🏷️ Test sale notification sent!")
    }
    
    private func sendTestPriceDropNotification() {
        scheduleTestNotification(
            title: "📉 Price Drop Alert!",
            body: "Kirkland Signature Organic Coconut Oil dropped $5.00 to $19.99",
            delay: 2
        )
        AppLogger.logDataOperation("Test price drop notification triggered", success: true)
        print("📉 Test price drop notification sent!")
    }
    
    private func sendTestReceiptNotification() {
        scheduleTestNotification(
            title: "✅ Receipt Processed!",
            body: "Receipt #TEST123456 processed with 15 items",
            delay: 2
        )
        AppLogger.logDataOperation("Test receipt notification triggered", success: true)
        print("✅ Test receipt notification sent!")
    }
    
    private func sendAdvancedTestNotification() {
        // Send a custom notification with advanced features
        let content = UNMutableNotificationContent()
        content.title = "🧪 Advanced Test"
        content.body = "This is an advanced notification test with custom timing and actions."
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.logError(error, context: "Advanced test notification")
                } else {
                    AppLogger.logDataOperation("Advanced test notification scheduled", success: true)
                }
            }
        }
        
        print("🔬 Advanced test notification scheduled for 3 seconds!")
    }
    
    private func scheduleTestNotification(title: String, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Notification scheduling failed: \(error.localizedDescription)")
                    AppLogger.logError(error, context: "Notification scheduling")
                } else {
                    print("✅ Notification scheduled: \(title)")
                }
            }
        }
    }
    
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🔍 Notification Permission Status:")
                print("  - Authorization: \(settings.authorizationStatus.rawValue)")
                print("  - Alert Setting: \(settings.alertSetting.rawValue)")
                print("  - Badge Setting: \(settings.badgeSetting.rawValue)")
                print("  - Sound Setting: \(settings.soundSetting.rawValue)")
                print("  - Notification Center: \(settings.notificationCenterSetting.rawValue)")
                print("  - Lock Screen: \(settings.lockScreenSetting.rawValue)")
                print("  - Car Play: \(settings.carPlaySetting.rawValue)")
                
                switch settings.authorizationStatus {
                case .authorized:
                    print("✅ Notifications are AUTHORIZED")
                case .denied:
                    print("❌ Notifications are DENIED - User needs to enable in Settings")
                case .notDetermined:
                    print("⚠️ Notifications are NOT DETERMINED - Need to request permission")
                    // Request permission
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            if granted {
                                print("✅ Permission granted!")
                            } else {
                                print("❌ Permission denied: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                case .provisional:
                    print("⚠️ Notifications are PROVISIONAL")
                case .ephemeral:
                    print("⚠️ Notifications are EPHEMERAL")
                @unknown default:
                    print("⚠️ Unknown notification authorization status")
                }
                
                AppLogger.logDataOperation("Notification permissions checked", success: true)
            }
        }
    }
    #endif
    
    // MARK: - Biometric Authentication
    
    private var biometricIconName: String {
        switch biometricService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "person.crop.circle.badge.checkmark"
        }
    }
    
    private func enableBiometricAuthFromSettings() async {
        guard let user = authService.currentUser else { 
            AppLogger.logWarning("No current user found for biometric setup", context: "BiometricAuth")
            await MainActor.run {
                enteredPassword = ""
            }
            return 
        }
        
        guard !enteredPassword.isEmpty else {
            AppLogger.logWarning("No password entered for biometric setup", context: "BiometricAuth")
            await MainActor.run {
                enteredPassword = ""
            }
            return
        }
        
        AppLogger.logSecurityEvent("Starting biometric auth setup for user: \(user.email)")
        
        // Try to enable biometric auth - this will prompt for biometric authentication
        let success = await biometricService.setupBiometricAuth(
            email: user.email, 
            password: enteredPassword
        )
        
        await MainActor.run {
            // Always clear the password for security
            enteredPassword = ""
            
            if success {
                AppLogger.logSecurityEvent("Biometric authentication setup completed successfully")
            } else {
                let errorMsg = biometricService.biometricError ?? "Unknown error"
                AppLogger.logError(BiometricError.authenticationFailed, context: "Biometric setup")
                
                // Show error to user if it's a credential validation issue
                if errorMsg.contains("Invalid password") {
                    // Show the password prompt again for retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingPasswordPrompt = true
                    }
                }
                print("Failed to enable biometric authentication: \(errorMsg)")
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.accentColor)
                .frame(width: 25)
            Text(title)
                .foregroundColor(themeManager.primaryTextColor)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var receiptAlerts = true
    @State private var priceDrops = true
    @State private var weeklyReport = false
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            List {
                Section(header: Text("Notifications")
                    .foregroundColor(themeManager.secondaryTextColor)) {
                    
                    HStack {
                        Text("Receipt Processing Alerts")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Toggle("", isOn: $receiptAlerts)
                            .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                    }
                    
                    HStack {
                        Text("Price Drop Alerts")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Toggle("", isOn: $priceDrops)
                            .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                    }
                    
                    HStack {
                        Text("Weekly Summary Report")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Toggle("", isOn: $weeklyReport)
                            .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                    }
                }
                .listRowBackground(themeManager.cardBackgroundColor)
            }
            .background(Color.clear)
            .onAppear {
                UITableView.appearance().backgroundColor = UIColor.clear
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DataManagementView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var showingClearDataAlert = false
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            List {
                Section(header: Text("Data Management")
                    .foregroundColor(themeManager.secondaryTextColor)) {
                    
                    Button(action: {
                        receiptStore.syncWithServer()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(themeManager.accentColor)
                                .frame(width: 25)
                            Text("Sync Data")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        showingClearDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 25)
                            Text("Clear Local Data")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(themeManager.cardBackgroundColor)
            }
            .background(Color.clear)
            .onAppear {
                UITableView.appearance().backgroundColor = UIColor.clear
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Local Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                receiptStore.clearAllLocalReceipts()
            }
        } message: {
            Text("This will remove all locally stored receipts. Your data on the server will remain safe.")
        }
    }
}

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Personal Information")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        TextField("First Name", text: $firstName)
                            .foregroundColor(themeManager.primaryTextColor)
                        TextField("Last Name", text: $lastName)
                            .foregroundColor(themeManager.primaryTextColor)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                }
                .background(Color.clear)
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    // TODO: Implement save functionality
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.accentColor)
            )
        }
        .onAppear {
            if let user = authService.currentUser {
                firstName = user.firstName ?? ""
                lastName = user.lastName ?? ""
                email = user.email
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Change Password")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        SecureField("Current Password", text: $currentPassword)
                            .foregroundColor(themeManager.primaryTextColor)
                        SecureField("New Password", text: $newPassword)
                            .foregroundColor(themeManager.primaryTextColor)
                        SecureField("Confirm New Password", text: $confirmPassword)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                }
                .background(Color.clear)
            }
            .navigationTitle("Change Password")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    // TODO: Implement password change functionality
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeManager.accentColor)
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(ThemeManager())
} 