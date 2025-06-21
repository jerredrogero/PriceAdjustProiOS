import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingLogoutAlert = false
    
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
                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                themeManager: themeManager
                            )
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