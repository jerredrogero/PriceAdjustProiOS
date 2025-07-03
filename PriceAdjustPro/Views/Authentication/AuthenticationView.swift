import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                Image("costco_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .padding(.top, 50)
                
                Text("PriceAdjustPro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if isRegistering {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                if authService.isLoading {
                    ProgressView()
                } else {
                    Button(action: {
                        if isRegistering {
                            authService.register(email: email, password: password, firstName: firstName, lastName: lastName)
                        } else {
                            authService.login(email: email, password: password)
                        }
                    }) {
                        Text(isRegistering ? "Register" : "Login")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Biometric Authentication Button (only show for login)
                if !isRegistering && biometricService.isBiometricAvailable && biometricService.isBiometricEnabled {
                    Button(action: {
                        authService.loginWithBiometrics()
                    }) {
                        HStack {
                            Image(systemName: biometricIconName)
                                .font(.title2)
                            Text("Sign in with \(biometricService.biometricTypeString)")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                Button(action: {
                    withAnimation {
                        isRegistering.toggle()
                    }
                }) {
                    Text(isRegistering ? "Already have an account? Login" : "Don't have an account? Register")
                        .foregroundColor(.red)
                }
                
                if let error = authService.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                }
            }
            .navigationBarHidden(true)
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



#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
} 