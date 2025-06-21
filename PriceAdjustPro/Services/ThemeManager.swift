import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    init() {
        // Default to dark mode (since we just implemented it)
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // Theme colors
    var backgroundColor: Color {
        isDarkMode ? .black : .white
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(.systemBackground)
    }
    
    var primaryTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? .gray : Color(.systemGray)
    }
    
    var accentColor: Color {
        .red
    }
    
    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }
} 