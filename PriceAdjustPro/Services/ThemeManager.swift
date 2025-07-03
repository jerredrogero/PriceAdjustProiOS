import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    init() {
        // Default to system preference if not set
        if let savedMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool {
            self.isDarkMode = savedMode
        } else {
            // Check system preference
            self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // Theme colors
    var backgroundColor: Color {
        isDarkMode ? .black : Color(.systemBackground)
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(.secondarySystemBackground)
    }
    
    var listRowBackgroundColor: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(.systemBackground)
    }
    
    var primaryTextColor: Color {
        isDarkMode ? .white : Color(.label)
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? .gray : Color(.secondaryLabel)
    }
    
    var accentColor: Color {
        Color("costcoRed") // Using the Costco red from assets
    }
    
    var successColor: Color {
        .green
    }
    
    var warningColor: Color {
        .orange
    }
    
    var errorColor: Color {
        .red
    }
    
    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }
} 