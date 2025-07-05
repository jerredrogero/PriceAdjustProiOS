import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showPassword = false
    @State private var isKeyboardVisible = false
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if isRegistering {
            let firstNameValid = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let lastNameValid = !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return emailValid && passwordValid && firstNameValid && lastNameValid
        } else {
            return emailValid && passwordValid
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background Gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.costcoRed,
                            Color.costcoRed.opacity(0.8),
                            themeManager.backgroundColor
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header Section
                            HeaderSection()
                                .padding(.top, geometry.safeAreaInsets.top + 40)
                            
                            // Main Content Card
                            MainContentCard()
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                            
                            Spacer(minLength: 50)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .alert("Enable \(biometricService.biometricTypeString)?", isPresented: $authService.shouldOfferBiometricSetup) {
                Button("Enable") {
                    authService.enableBiometricAuth()
                }
                Button("Not Now", role: .cancel) {
                    authService.declineBiometricAuth()
                }
            } message: {
                Text("Use \(biometricService.biometricTypeString) for quick and secure login to PriceAdjustPro.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(spacing: 20) {
            // Logo and App Name
            VStack(spacing: 16) {
                // Costco Logo with Shadow
                Image("costco_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .shadow(radius: 10)
                    .accessibilityLabel("Costco Logo")
                    .accessibilityIdentifier("costco-logo")
                
                // App Title with Animation
                VStack(spacing: 8) {
                    Text("PriceAdjustPro")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.white, .white.opacity(0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(radius: 2)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("app-title")
                    
                    Text("Automate your refund rights")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.medium)
                        .accessibilityLabel("App tagline: Automate your refund rights")
                        .accessibilityIdentifier("app-tagline")
                }
            }
            
            // Welcome Message
            Text(isRegistering ? "Create Your Account" : "Welcome Back")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .opacity(isKeyboardVisible ? 0 : 1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(isRegistering ? "create-account-header" : "welcome-back-header")
        }
        .animation(.easeInOut(duration: 0.3), value: isKeyboardVisible)
        .animation(.easeInOut(duration: 0.5), value: isRegistering)
    }
    
    // MARK: - Main Content Card
    @ViewBuilder
    private func MainContentCard() -> some View {
        VStack(spacing: 24) {
            // Form Fields
            VStack(spacing: 16) {
                if isRegistering {
                    // Registration Fields
                    HStack(spacing: 12) {
                        ModernTextField(
                            title: "First Name *",
                            text: $firstName,
                            icon: "person",
                            placeholder: "Enter first name"
                        )
                        .onChange(of: firstName) { _ in
                            authService.clearError()
                        }
                        
                        ModernTextField(
                            title: "Last Name *",
                            text: $lastName,
                            icon: "person.badge.plus",
                            placeholder: "Enter last name"
                        )
                        .onChange(of: lastName) { _ in
                            authService.clearError()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Email Field
                ModernTextField(
                    title: "Email or Username *",
                    text: $email,
                    icon: "envelope",
                    placeholder: "Enter your email or username",
                    keyboardType: .emailAddress
                )
                .onChange(of: email) { _ in
                    authService.clearError()
                }
                
                // Password Field
                ModernPasswordField(
                    title: "Password *",
                    text: $password,
                    showPassword: $showPassword,
                    placeholder: "Enter your password"
                )
                .onChange(of: password) { _ in
                    authService.clearError()
                }
            }
            
            // Error Message
            if let error = authService.errorMessage {
                ErrorMessageView(message: error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Action Buttons
            VStack(spacing: 16) {
                // Primary Action Button
                PrimaryActionButton(
                    title: isRegistering ? "Create Account" : "Sign In",
                    isLoading: authService.isLoading,
                    isEnabled: isFormValid,
                    action: {
                        if isRegistering {
                            // Validate all fields before sending
                            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                authService.errorMessage = "Please fill in all fields"
                                return
                            }
                            
                            // Debug logging
                            print("📝 Registration attempt with:")
                            print("   Email: '\(email)'")
                            print("   Password: [length: \(password.count)]")
                            print("   First Name: '\(firstName)'")
                            print("   Last Name: '\(lastName)'")
                            
                            authService.register(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password,
                                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        } else {
                            // Validate login fields
                            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                authService.errorMessage = "Please enter your email and password"
                                return
                            }
                            
                            authService.login(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            )
                        }
                    }
                )
                
                // Biometric Authentication (Login only)
                if !isRegistering && biometricService.isBiometricAvailable && biometricService.isBiometricEnabled {
                    BiometricAuthButton(
                        biometricType: biometricService.biometricTypeString,
                        iconName: biometricIconName,
                        action: {
                            authService.loginWithBiometrics()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                // Toggle Auth Mode
                ToggleAuthModeButton(
                    isRegistering: $isRegistering
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 20)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRegistering)
    }
    
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
}

// MARK: - Custom Components

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.secondaryTextColor)
                .opacity(isFocused || !text.isEmpty ? 1 : 0.7)
                .accessibilityHidden(true) // Hide label since TextField will include it
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? themeManager.accentColor : themeManager.secondaryTextColor)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .accessibilityHidden(true) // Decorative icon
                
                TextField(placeholder, text: $text)
                    .foregroundColor(themeManager.primaryTextColor)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .focused($isFocused)
                    .accessibilityLabel(title)
                    .accessibilityHint(placeholder)
                    .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: " ", with: "-"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? themeManager.accentColor : themeManager.secondaryTextColor.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ModernPasswordField: View {
    let title: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let placeholder: String
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.secondaryTextColor)
                .opacity(isFocused || !text.isEmpty ? 1 : 0.7)
                .accessibilityHidden(true) // Hide label since TextField will include it
            
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundColor(isFocused ? themeManager.accentColor : themeManager.secondaryTextColor)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .accessibilityHidden(true) // Decorative icon
                
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .foregroundColor(themeManager.primaryTextColor)
                .focused($isFocused)
                .accessibilityLabel(title)
                .accessibilityHint(placeholder)
                .accessibilityIdentifier("password-field")
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                .accessibilityHint("Toggles password visibility")
                .accessibilityIdentifier("password-visibility-toggle")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? themeManager.accentColor : themeManager.secondaryTextColor.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(themeManager.errorColor)
                .accessibilityHidden(true) // Decorative icon
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(themeManager.errorColor)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.errorColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.errorColor.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityLabel("Error: \(message)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("error-message")
    }
}

struct PrimaryActionButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .accessibilityLabel("Loading")
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .accessibilityHidden(true) // Decorative icon
                }
                
                Text(isLoading ? "Processing..." : title)
                    .fontWeight(.semibold)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.accentColor,
                        themeManager.accentColor.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading || !isEnabled)
        .opacity((isLoading || !isEnabled) ? 0.6 : 1.0)
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel(isLoading ? "Processing" : title)
        .accessibilityHint(isLoading ? "Please wait" : "Tap to \(title.lowercased())")
        .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: " ", with: "-") + "-button")
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isEnabled ? [] : .isButton)
    }
}

struct BiometricAuthButton: View {
    let biometricType: String
    let iconName: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .font(.title3)
                    .accessibilityHidden(true) // Decorative icon
                
                Text("Sign in with \(biometricType)")
                    .fontWeight(.medium)
            }
            .foregroundColor(themeManager.primaryTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel("Sign in with \(biometricType)")
        .accessibilityHint("Uses biometric authentication to sign in")
        .accessibilityIdentifier("biometric-auth-button")
        .accessibilityAddTraits(.isButton)
    }
}

struct ToggleAuthModeButton: View {
    @Binding var isRegistering: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isRegistering.toggle()
            }
        }) {
            HStack {
                Text(isRegistering ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Text(isRegistering ? "Sign In" : "Sign Up")
                    .foregroundColor(themeManager.accentColor)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding(.top, 8)
        .accessibilityLabel(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
        .accessibilityHint(isRegistering ? "Switches to sign in mode" : "Switches to sign up mode")
        .accessibilityIdentifier("toggle-auth-mode-button")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
        .environmentObject(ThemeManager())
} 