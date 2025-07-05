import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var accentColor: Color = Color.costcoRed
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadTheme()
    }
    
    // MARK: - Theme Colors
    
    var backgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }
    
    var primaryTextColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color.gray : Color.gray
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color.gray.opacity(0.2) : Color.white
    }
    
    var listRowBackgroundColor: Color {
        isDarkMode ? Color.gray.opacity(0.1) : Color(.systemBackground)
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // Status Colors
    var successColor: Color { .green }
    var warningColor: Color { .orange }
    var errorColor: Color { .red }
    
    // MARK: - Accessibility & Dynamic Type Support
    
    /// Accessible font that scales with Dynamic Type
    func accessibleFont(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        // Use basic system font for iOS 15 compatibility
        return Font.system(textStyle).weight(weight)
    }
    
    /// Custom font size that respects accessibility settings
    func accessibleFontSize(base: CGFloat, textStyle: Font.TextStyle = .body) -> CGFloat {
        let scaleFactor = UIFontMetrics(forTextStyle: textStyle.uiKit).scaledValue(for: base)
        return scaleFactor
    }
    
    // MARK: - Theme Management
    
    func toggleTheme() {
        isDarkMode.toggle()
        saveTheme()
    }
    
    func setTheme(_ darkMode: Bool) {
        isDarkMode = darkMode
        saveTheme()
    }
    
    private func loadTheme() {
        isDarkMode = userDefaults.bool(forKey: "isDarkMode")
    }
    
    private func saveTheme() {
        userDefaults.set(isDarkMode, forKey: "isDarkMode")
    }
}

// MARK: - Font.TextStyle Extension for UIKit Compatibility

extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

// MARK: - Accessibility Extension for Views

extension View {
    /// Adds comprehensive accessibility support to any view
    func accessibilitySupport(
        label: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        self
            .modifier(AccessibilityModifier(
                label: label,
                hint: hint,
                identifier: identifier,
                traits: traits,
                value: value
            ))
    }
}

struct AccessibilityModifier: ViewModifier {
    let label: String?
    let hint: String?
    let identifier: String?
    let traits: AccessibilityTraits
    let value: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
} 