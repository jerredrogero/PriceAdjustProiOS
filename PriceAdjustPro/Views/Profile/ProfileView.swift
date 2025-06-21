import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // User Profile Section
                    if let user = authService.currentUser {
                        VStack(alignment: .center, spacing: 20) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(themeManager.accentColor)
                            
                            Text(displayName(for: user))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Text("Member")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .padding()
                    }
                    
                    // Settings Button
                    Button(action: {
                        showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                            Text("Settings")
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.accentColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService())
        .environmentObject(ThemeManager())
} 