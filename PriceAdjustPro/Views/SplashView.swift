import SwiftUI

struct SplashView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background - solid theme color
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.8), value: isAnimating)
                
                // App Name
                Text("PriceAdjustPro")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: isAnimating)
                
                // Tagline
                Text("AI Powered Receipt Tracking")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.4), value: isAnimating)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentColor))
                    .scaleEffect(1.2)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.6), value: isAnimating)
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(ThemeManager())
}