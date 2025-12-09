//
//  PriceAdjustProWidget.swift
//  PriceAdjustProWidget
//
//  Created by Jerred Rogero on 12/9/25.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct UploadReceiptEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UploadReceiptEntry {
        UploadReceiptEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (UploadReceiptEntry) -> ()) {
        let entry = UploadReceiptEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UploadReceiptEntry>) -> ()) {
        let entry = UploadReceiptEntry(date: Date())
        // Widget doesn't need to update - it's just a button
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    var entry: UploadReceiptEntry
    
    var body: some View {
        ZStack {
            // Costco red background
            Color(red: 0.78, green: 0.12, blue: 0.24)
            
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Upload")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Receipt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .widgetURL(URL(string: "priceadjustpro://upload"))
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    var entry: UploadReceiptEntry
    
    var body: some View {
        ZStack {
            // Costco red background
            Color(red: 0.78, green: 0.12, blue: 0.24)
            
            VStack(spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("PriceAdjustPro")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                
                // Action buttons row
                HStack(spacing: 10) {
                    // Upload Receipt - Primary action
                    Link(destination: URL(string: "priceadjustpro://upload")!) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Upload")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // View Receipts
                    Link(destination: URL(string: "priceadjustpro://receipts")!) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Receipts")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // On Sale
                    Link(destination: URL(string: "priceadjustpro://onsale")!) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("On Sale")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Analytics
                    Link(destination: URL(string: "priceadjustpro://analytics")!) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Analytics")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Lock Screen Circular Widget
struct LockScreenCircularView: View {
    var entry: UploadReceiptEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
        .widgetURL(URL(string: "priceadjustpro://upload"))
    }
}

// MARK: - Lock Screen Rectangular Widget
struct LockScreenRectangularView: View {
    var entry: UploadReceiptEntry
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Upload Receipt")
                    .font(.system(size: 12, weight: .bold))
                Text("Tap to scan")
                    .font(.system(size: 10))
                    .opacity(0.8)
            }
        }
        .widgetURL(URL(string: "priceadjustpro://upload"))
    }
}

// MARK: - Lock Screen Inline Widget
struct LockScreenInlineView: View {
    var entry: UploadReceiptEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.fill")
            Text("Upload Receipt")
        }
        .widgetURL(URL(string: "priceadjustpro://upload"))
    }
}

// MARK: - Widget Entry View
struct PriceAdjustProWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
struct PriceAdjustProWidget: Widget {
    let kind: String = "PriceAdjustProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PriceAdjustProWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 0.78, green: 0.12, blue: 0.24), for: .widget)
            } else {
                PriceAdjustProWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Upload Receipt")
        .description("Quickly upload a new receipt to PriceAdjustPro.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,      // Lock screen circular
            .accessoryRectangular,   // Lock screen rectangular
            .accessoryInline         // Lock screen inline (above time)
        ])
    }
}

// MARK: - Previews

#Preview("Home Screen - Small", as: .systemSmall) {
    PriceAdjustProWidget()
} timeline: {
    UploadReceiptEntry(date: .now)
}

#Preview("Home Screen - Medium", as: .systemMedium) {
    PriceAdjustProWidget()
} timeline: {
    UploadReceiptEntry(date: .now)
}

#Preview("Lock Screen - Circular", as: .accessoryCircular) {
    PriceAdjustProWidget()
} timeline: {
    UploadReceiptEntry(date: .now)
}

#Preview("Lock Screen - Rectangular", as: .accessoryRectangular) {
    PriceAdjustProWidget()
} timeline: {
    UploadReceiptEntry(date: .now)
}

#Preview("Lock Screen - Inline", as: .accessoryInline) {
    PriceAdjustProWidget()
} timeline: {
    UploadReceiptEntry(date: .now)
}
