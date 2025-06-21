import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthenticationService
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
        }
    }
}



#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
} 