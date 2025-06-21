# PriceAdjustPro iOS

A native iOS application for managing and analyzing Costco receipts. Built with SwiftUI and Core Data, providing a seamless mobile experience for receipt tracking and expense analysis.

## Features

### 📱 Core Functionality
- **PDF Receipt Processing**: Upload and automatically parse PDF receipts using OCR
- **Camera Integration**: Capture receipts directly with your iPhone camera
- **Photo Library Support**: Import receipt images from your photo library
- **Real-time Text Extraction**: Advanced PDF text parsing and OCR capabilities
- **Secure Authentication**: User registration and login with keychain storage

### 🗄️ Data Management
- **Core Data Integration**: Local storage with automatic sync
- **Cloud Backup**: Server synchronization for data protection
- **Search & Filter**: Advanced receipt search and filtering capabilities
- **Export Options**: PDF, CSV, and JSON export formats
- **Offline Support**: Full functionality without internet connection

### 📊 Analytics & Insights
- **Spending Analysis**: Track expenses over time with interactive charts
- **Category Breakdown**: Visualize spending by product categories
- **Monthly/Yearly Reports**: Comprehensive spending reports
- **Receipt Statistics**: Track total receipts and average spending

### 🎨 User Experience
- **Native iOS Design**: Follows Apple Human Interface Guidelines
- **Costco Branding**: Authentic color scheme and design elements
- **Dark Mode Support**: Automatic light/dark mode adaptation
- **Accessibility**: VoiceOver and Dynamic Type support
- **Pull-to-Refresh**: Intuitive data synchronization

## Technical Stack

### Frameworks & Technologies
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence
- **PDFKit**: PDF processing and viewing
- **Vision**: OCR and text recognition
- **Combine**: Reactive programming for data flow
- **Charts**: Native chart visualizations (iOS 16+)
- **KeychainAccess**: Secure credential storage

### Architecture
- **MVVM Pattern**: Model-View-ViewModel architecture
- **Service Layer**: Dedicated services for API, PDF, and authentication
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Environment objects for state management

## Project Structure

```
PriceAdjustPro/
├── App/
│   ├── PriceAdjustProApp.swift      # Main app entry point
│   └── ContentView.swift            # Root view with authentication flow
├── Models/
│   └── PersistenceController.swift  # Core Data stack management
├── ViewModels/
│   └── ReceiptStore.swift           # Main receipt management ViewModel
├── Services/
│   ├── APIService.swift             # Django backend communication
│   ├── AuthenticationService.swift  # User authentication
│   └── PDFService.swift             # PDF processing and OCR
├── Views/
│   ├── Authentication/
│   │   └── AuthenticationView.swift # Login/registration interface
│   ├── Receipts/
│   │   ├── ReceiptListView.swift    # Receipt list with search
│   │   ├── ReceiptDetailView.swift  # Detailed receipt view
│   │   └── AddReceiptView.swift     # Receipt upload interface
│   ├── Analytics/
│   │   └── AnalyticsView.swift      # Spending insights and charts
│   └── Profile/
│       └── ProfileView.swift        # User profile and settings
├── Resources/
│   └── Assets.xcassets              # App icons and color assets
└── PriceAdjustPro.xcdatamodeld      # Core Data model
```

## Core Data Model

### Entities

**Receipt**
- `id`: UUID (Primary Key)
- `receiptNumber`: String (Optional)
- `storeName`: String (Optional)
- `storeLocation`: String (Optional)
- `date`: Date
- `subtotal`: Double
- `tax`: Double
- `total`: Double
- `pdfData`: Binary Data (Optional)
- `imageData`: Binary Data (Optional)
- `notes`: String (Optional)
- `isProcessed`: Boolean
- `processingStatus`: String
- `createdAt`: Date
- `updatedAt`: Date

**LineItem**
- `id`: UUID (Primary Key)
- `name`: String
- `price`: Double
- `quantity`: Int32
- `itemCode`: String (Optional)
- `category`: String (Optional)
- `isRefunded`: Boolean

**User**
- `id`: UUID (Primary Key)
- `email`: String
- `firstName`: String
- `lastName`: String
- `profileImageData`: Binary Data (Optional)
- `preferences`: String (Optional)
- `createdAt`: Date
- `lastLoginAt`: Date
- `isActive`: Boolean

## API Integration

### Backend Communication
The app communicates with the Django backend through a RESTful API:

```swift
// Authentication
POST /api/auth/login/
POST /api/auth/register/
POST /api/auth/refresh/

// Receipts
GET /api/receipts/
POST /api/receipts/upload/
GET /api/receipts/{id}/
DELETE /api/receipts/{id}/
```

### Authentication Flow
1. User credentials stored securely in Keychain
2. JWT tokens for API authentication
3. Automatic token refresh
4. Secure logout with token invalidation

## Setup Instructions

### Prerequisites
- Xcode 15.0+ (for iOS 15.0+ support)
- iOS Simulator or physical device
- macOS 14.0+ (Sonoma)

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/jerredrogero/PriceAdjustPro-iOS.git
   cd PriceAdjustPro-iOS
   ```

2. **Open in Xcode**
   ```bash
   open PriceAdjustPro.xcodeproj
   ```

3. **Configure Backend URL**
   Update the API base URL in `APIService.swift`:
   ```swift
   private let baseURL = "https://your-backend-url.com/api"
   ```

4. **Add Dependencies**
   Add `KeychainAccess` via Swift Package Manager:
   - File → Add Package Dependencies
   - Enter: `https://github.com/kishikawakatsumi/KeychainAccess`

5. **Build and Run**
   - Select target device/simulator
   - Press Cmd+R to build and run

### Configuration

**Info.plist Permissions**
The app requires these permissions (already configured):
- `NSCameraUsageDescription`: Camera access for receipt capture
- `NSPhotoLibraryUsageDescription`: Photo library access
- `NSDocumentPickerUsageDescription`: Document access for PDF upload

**Build Settings**
- Deployment Target: iOS 15.0
- Swift Version: Swift 5
- Bundle Identifier: `com.priceadjustpro.ios`

## Key Features Implementation

### PDF Processing
```swift
// OCR text extraction from images/PDFs
let request = VNRecognizeTextRequest { request, error in
    // Process recognized text
}
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
```

### Receipt Parsing
```swift
// Extract receipt data from text
private func parseReceiptText(_ text: String) -> ReceiptData {
    // Regex patterns for dates, amounts, item names
    // Store name detection
    // Line item extraction
}
```

### Chart Integration
```swift
// iOS 16+ Charts framework
Chart(chartData, id: \.period) { data in
    BarMark(
        x: .value("Period", data.period),
        y: .value("Amount", data.amount)
    )
    .foregroundStyle(Color.costcoBlue.gradient)
}
```

## Performance Considerations

### Memory Management
- Lazy loading for large receipt lists
- Image compression for storage efficiency
- Automatic cleanup of temporary PDF files

### Data Optimization
- Core Data batch operations
- Background context for heavy operations
- Efficient search with NSPredicate

### UI Performance
- SwiftUI view modifiers for smooth animations
- Async image loading
- Progressive disclosure for large datasets

## Testing Strategy

### Unit Tests
- ReceiptStore business logic
- PDF parsing accuracy
- API service functionality
- Data model validation

### UI Tests
- Authentication flow
- Receipt upload process
- Navigation between views
- Search and filter operations

### Integration Tests
- Core Data operations
- API communication
- PDF processing pipeline

## Security Measures

### Data Protection
- Keychain storage for sensitive data
- Core Data encryption at rest
- Secure API token management
- Certificate pinning for API calls

### Privacy
- Local-first data storage
- Optional cloud sync
- No tracking or analytics
- User consent for data export

## Future Enhancements

### Planned Features
- **Receipt Sharing**: Share receipts with family members
- **Price Tracking**: Monitor price changes over time
- **Budget Alerts**: Spending limit notifications
- **Widget Support**: Home screen spending widgets
- **Apple Pay Integration**: Link with transaction data
- **Siri Shortcuts**: Voice-activated receipt capture

### Technical Improvements
- **Background Processing**: Automatic receipt processing
- **Machine Learning**: Improved categorization
- **CloudKit Integration**: Native iCloud sync
- **WatchOS Companion**: Apple Watch support

## Contributing

### Development Workflow
1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Code Standards
- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write unit tests for new features
- Update documentation for API changes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Core Data Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)

### Contact
- **Email**: support@priceadjustpro.com
- **GitHub Issues**: [PriceAdjustPro-iOS Issues](https://github.com/jerredrogero/PriceAdjustPro-iOS/issues)
- **Website**: [priceadjustpro.com](https://priceadjustpro.com)

## Acknowledgments

- **Costco Wholesale**: Inspiration for retail receipt management
- **Apple**: SwiftUI and iOS development frameworks
- **Open Source Community**: Dependencies and libraries used

---

Built with ❤️ for iOS developers and Costco shoppers everywhere. 