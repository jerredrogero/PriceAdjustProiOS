import SwiftUI
import Combine

struct EmailVerificationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    let userEmail: String
    
    @State private var verificationCode = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isResending = false
    @State private var canResend = true
    @State private var resendCountdown = 0
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background - solid red
                    Color.costcoRed
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
        }
        .onAppear {
            // Auto-focus the code field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCodeFieldFocused = true
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(.white)
                .shadow(radius: 10)
                .accessibilityLabel("Email Verification")
            
            // Title
            Text("Verify Your Email")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 2)
                .accessibilityAddTraits(.isHeader)
            
            // Subtitle
            Text("We sent a verification code to")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            Text(userEmail)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Main Content Card
    @ViewBuilder
    private func MainContentCard() -> some View {
        VStack(spacing: 24) {
            // Instructions
            VStack(spacing: 12) {
                Text("Enter the 6-digit code")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Check your email inbox and spam folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            
            // Verification Code Field
            VerificationCodeField(
                code: $verificationCode,
                isFocused: $isCodeFieldFocused
            )
            .onChange(of: verificationCode) { newValue in
                // Clear errors when user types
                errorMessage = nil
                successMessage = nil
                
                // Auto-submit when 6 digits are entered
                if newValue.count == 6 {
                    verifyCode()
                }
            }
            
            // Error/Success Messages
            if let error = errorMessage {
                MessageView(message: error, isError: true)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            if let success = successMessage {
                MessageView(message: success, isError: false)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Action Buttons
            VStack(spacing: 16) {
                // Verify Button
                Button(action: verifyCode) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }
                        
                        Text(isVerifying ? "Verifying..." : "Verify Email")
                            .fontWeight(.semibold)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.costcoRed,
                                Color.costcoRed.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.costcoRed.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isVerifying || verificationCode.count != 6)
                .opacity((isVerifying || verificationCode.count != 6) ? 0.6 : 1.0)
                
                // Resend Button
                ResendButton()
                
                // Skip for now button
                Button(action: {
                    // Allow user to skip verification and use app with limited features
                    authService.skipEmailVerification()
                }) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: errorMessage)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: successMessage)
    }
    
    // MARK: - Resend Button
    @ViewBuilder
    private func ResendButton() -> some View {
        Button(action: resendVerificationEmail) {
            HStack {
                if isResending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.costcoBlue))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(canResend ? Color.costcoBlue : .gray)
                }
                
                if resendCountdown > 0 {
                    Text("Resend in \(resendCountdown)s")
                        .foregroundColor(.gray)
                } else {
                    Text("Resend Code")
                        .foregroundColor(canResend ? Color.costcoBlue : .gray)
                }
            }
            .font(.system(size: 15, weight: .medium))
        }
        .disabled(!canResend || isResending)
    }
    
    // MARK: - Actions
    
    private func verifyCode() {
        guard verificationCode.count == 6 else {
            errorMessage = "Please enter a valid 6-digit code"
            return
        }
        
        isVerifying = true
        errorMessage = nil
        successMessage = nil
        
        APIService.shared.verifyEmail(code: verificationCode)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isVerifying = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { response in
                    if response.isSuccess {
                        self.successMessage = "Email verified successfully!"
                        
                        // Update user verification status
                        if let user = response.user {
                            self.authService.updateUserVerificationStatus(user: user)
                        }
                        
                        // Dismiss after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.authService.completeEmailVerification()
                        }
                    } else {
                        self.errorMessage = response.errorMessage ?? "Verification failed. Please try again."
                    }
                }
            )
            .store(in: &self.authService.cancellables)
    }
    
    private func resendVerificationEmail() {
        guard canResend else { return }
        
        isResending = true
        errorMessage = nil
        successMessage = nil
        
        APIService.shared.resendVerificationEmail(email: userEmail)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isResending = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { response in
                    if response.isSuccess {
                        self.successMessage = response.displayMessage
                        self.startResendCooldown()
                    } else {
                        self.errorMessage = response.displayMessage
                    }
                }
            )
            .store(in: &self.authService.cancellables)
    }
    
    private func startResendCooldown() {
        canResend = false
        resendCountdown = 60
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
                canResend = true
            }
        }
    }
}

// MARK: - Verification Code Field

struct VerificationCodeField: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        ZStack {
            // Hidden TextField for actual input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .focused(isFocused)
                .onChange(of: code) { newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                    // Only allow numbers
                    code = newValue.filter { $0.isNumber }
                }
            
            // Visual representation of code boxes
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitBox(
                        digit: code.count > index ? String(code[code.index(code.startIndex, offsetBy: index)]) : "",
                        isActive: code.count == index
                    )
                }
            }
        }
        .onTapGesture {
            isFocused.wrappedValue = true
        }
    }
}

struct CodeDigitBox: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color.costcoRed : (digit.isEmpty ? Color.gray.opacity(0.3) : Color.costcoBlue),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .frame(width: 45, height: 56)
            
            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(digit.isEmpty ? .clear : .primary)
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: digit)
    }
}

// MARK: - Message View

struct MessageView: View {
    let message: String
    let isError: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(isError ? .red : .green)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((isError ? Color.red : Color.green).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isError ? Color.red : Color.green).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    EmailVerificationView(userEmail: "user@example.com")
        .environmentObject(AuthenticationService())
        .environmentObject(ThemeManager())
}

