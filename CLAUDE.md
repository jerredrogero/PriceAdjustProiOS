# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Open the Xcode project
open PriceAdjustPro.xcodeproj

# Build for iOS Simulator
xcodebuild -scheme PriceAdjustPro -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for iOS Device
xcodebuild -scheme PriceAdjustPro -destination generic/platform=iOS build

# Clean build
xcodebuild -scheme PriceAdjustPro clean

# Run on simulator (from Xcode)
# Cmd+R after selecting simulator target
```

**Note**: No automated testing, linting, or formatting tools are currently configured in this project.

## Architecture Overview

**PriceAdjustPro** is a native iOS receipt management app using MVVM architecture. This iOS app is the mobile client for the web application at https://github.com/jerredrogero/PriceAdjustPro.git and shares the same Django backend API.

### Core Architecture
- **Pattern**: MVVM (Model-View-ViewModel) with SwiftUI
- **Data Layer**: Core Data for local persistence + Django REST API sync
- **UI Framework**: SwiftUI with native iOS design patterns
- **Authentication**: Django session-based auth with keychain storage

### Key Service Layer
```
Services/
├── APIService.swift           # Django backend communication (baseURL: priceadjustpro.onrender.com)
├── AuthenticationService.swift # User auth + keychain management
├── PDFService.swift          # OCR processing with Vision framework
└── ThemeManager.swift        # Costco brand colors + dark mode
```

### Data Flow
1. **Local-First**: Core Data as primary storage
2. **Background Sync**: API sync on authentication/app launch
3. **Conflict Resolution**: Server takes precedence (manual edits protected)
4. **Models**: Receipt → LineItems (one-to-many), User entity

### Core Data Entities
- **Receipt**: Primary entity with PDF/image data, totals, processing status
- **LineItem**: Individual receipt items with price, quantity, category
- **User**: Authentication and profile data

## Project Structure Patterns

### ViewModels
- `ReceiptStore`: Central state management for all receipt operations
- Environment injection pattern for state sharing across views
- Combine publishers for reactive data flow

### Views Organization
```
Views/
├── Authentication/    # Login/registration flow
├── Receipts/         # Main CRUD operations (List, Detail, Add, Edit)
├── Analytics/        # Spending charts and insights
├── PriceAdjustments/ # Core feature - price comparison
├── OnSale/          # Costco promotions
└── Settings/Profile/ # User preferences
```

### API Integration Patterns
- REST endpoints with multipart form data for PDF uploads
- CSRF token handling for Django backend
- Automatic token refresh and session management
- Error handling with user-friendly messages

## Development Context

### Dependencies (Swift Package Manager)
- **KeychainAccess**: Secure credential storage
- **Core Frameworks**: SwiftUI, Core Data, PDFKit, Vision, Combine

### Key Features Implementation
- **PDF Processing**: Vision framework OCR for receipt text extraction
- **Camera Integration**: Native camera + photo library access
- **Background Processing**: Core Data background contexts
- **Theme System**: Costco branding (red/blue) with dark mode support

### Current State
- Main functionality implemented and working
- No unit tests or automated testing framework
- No SwiftLint or code formatting tools
- Recent development: Edit receipt functionality added

### Configuration Requirements
- **iOS 15.0+** deployment target
- **API Base URL**: Configure in APIService.swift (currently: priceadjustpro.onrender.com)
- **Permissions**: Camera, photo library, document picker (configured in Info.plist)
- **Bundle ID**: com.priceadjustpro.ios

## Code Conventions

### Swift/SwiftUI Patterns
- Use `@StateObject` for ViewModels, `@ObservedObject` for injection
- Core Data operations in background contexts for heavy operations
- Combine publishers for async operations and data binding
- Error handling with Result types and user-facing alerts

### Secure Logging (CRITICAL)
- **NEVER use `print()` for sensitive data** - use `AppLogger` utility instead
- `AppLogger.user()` for user actions, `AppLogger.apiCall()` for network requests
- `AppLogger.logError()` for errors, `AppLogger.logWarning()` for warnings
- Sensitive data automatically redacted in production builds
- Use structured logging categories (Network, Data, UI, Error)
- **Examples**:
  ```swift
  // ❌ NEVER DO THIS - exposes sensitive data
  print("API Response: \(jsonString)")
  
  // ✅ DO THIS - secure logging
  AppLogger.logResponseData(data, from: url.absoluteString)
  ```

### API Service Patterns
- Multipart form data for file uploads
- Session-based authentication with Django
- Centralized error handling in APIService
- Background queue operations for network calls

### UI/UX Conventions
- Follow native iOS patterns (NavigationStack, TabView, Sheet modals)
- Costco brand colors: costcoRed (#E31837), costcoBlue
- Support both light and dark mode
- Accessibility considerations (VoiceOver, Dynamic Type)