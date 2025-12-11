import SwiftUI
import PDFKit

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingPDFViewer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact Header
                CompactReceiptHeader(receipt: receipt)
                
                // Quick Summary Bar
                QuickSummaryBar(receipt: receipt)
                
                // Line Items (compact list)
                CompactLineItemsList(receipt: receipt)
                
                // Totals
                CompactTotalsSection(receipt: receipt)
                
                // PDF Preview (if available)
                if receipt.pdfData != nil {
                    CompactPDFSection(receipt: receipt, showingPDFViewer: $showingPDFViewer)
                }
                
                // Action Buttons
                CompactActionButtons(
                    showingEditSheet: $showingEditSheet,
                    showingShareSheet: $showingShareSheet,
                    showingDeleteAlert: $showingDeleteAlert
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            EditReceiptView(receipt: receipt)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: createShareItems())
        }
        .fullScreenCover(isPresented: $showingPDFViewer) {
            PDFViewerView(pdfData: receipt.pdfData)
        }
        .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
        } message: {
            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
    }
    
    private func createShareItems() -> [Any] {
        var items: [Any] = []
        
        let summary = createTextSummary()
        items.append(summary)
        
        if let pdfData = receipt.pdfData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("receipt_\(receipt.receiptNumber ?? "unknown").pdf")
            
            do {
                try pdfData.write(to: tempURL)
                items.append(tempURL)
            } catch {
                print("Error writing PDF to temp file: \(error)")
            }
        }
        
        return items
    }
    
    private func createTextSummary() -> String {
        var summary = "Receipt Summary\n\n"
        summary += "Store: \(receipt.storeName ?? "Unknown")\n"
        summary += "Date: \(receipt.formattedDate)\n"
        if let receiptNumber = receipt.receiptNumber {
            summary += "Receipt #: \(receiptNumber)\n"
        }
        summary += "\nItems:\n"
        
        for lineItem in receipt.lineItemsArray {
            summary += "• \(lineItem.name ?? "Unknown Item") - \(formatCurrency(lineItem.price))\n"
        }
        
        summary += "\nSubtotal: \(formatCurrency(receipt.subtotal))\n"
        summary += "Tax: \(formatCurrency(receipt.tax))\n"
        summary += "Total: \(formatCurrency(receipt.total))\n"
        
        return summary
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func deleteReceipt() {
        receiptStore.deleteReceipt(receipt)
    }
}

// MARK: - Compact Header

struct CompactReceiptHeader: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Store icon
            ZStack {
                Circle()
                    .fill(Color.costcoRed.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "building.2.fill")
                    .font(.title3)
                    .foregroundColor(.costcoRed)
            }
            
            // Store info
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.storeName ?? "Unknown Store")
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(receipt.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Total amount (prominent)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(receipt.total))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.costcoRed)
                
                if let receiptNumber = receipt.receiptNumber {
                    Text("#\(receiptNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Quick Summary Bar

struct QuickSummaryBar: View {
    let receipt: Receipt
    
    private var totalSavings: Double {
        receipt.lineItemsArray.reduce(0) { $0 + $1.instantSavings }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            SummaryPill(
                icon: "cart.fill",
                value: "\(receipt.lineItemsArray.count)",
                label: "Items"
            )
            
            Divider()
                .frame(height: 30)
            
            SummaryPill(
                icon: "minus.circle.fill",
                value: formatCurrency(receipt.subtotal),
                label: "Subtotal"
            )
            
            Divider()
                .frame(height: 30)
            
            if totalSavings > 0 {
                SummaryPill(
                    icon: "tag.fill",
                    value: formatCurrency(totalSavings),
                    label: "Savings",
                    valueColor: .green
                )
            } else {
                SummaryPill(
                    icon: "percent",
                    value: formatCurrency(receipt.tax),
                    label: "Tax"
                )
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String
    var valueColor: Color? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(valueColor ?? .costcoRed)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Line Items List

struct CompactLineItemsList: View {
    let receipt: Receipt
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Section header with collapse toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                // Items list
                VStack(spacing: 0) {
                    ForEach(Array(receipt.lineItemsArray.enumerated()), id: \.element.objectID) { index, lineItem in
                        CompactLineItemRow(lineItem: lineItem, isEven: index % 2 == 0)
                        
                        if index < receipt.lineItemsArray.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
    }
}

struct CompactLineItemRow: View {
    let lineItem: LineItem
    let isEven: Bool
    
    // Consider item on sale if either onSale flag is true OR instantSavings > 0
    private var isOnSale: Bool {
        lineItem.onSale || lineItem.instantSavings > 0
    }
    
    // The price on Costco receipts is the ORIGINAL price
    // The sale price is: original price - instant savings
    private var salePrice: Double {
        lineItem.price - lineItem.instantSavings
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Sale indicator bar on left for on-sale items
            if isOnSale {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 4)
            }
            
            // Item name and details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(lineItem.name ?? "Unknown Item")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    // Sale badge
                    if isOnSale {
                        HStack(spacing: 3) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 8))
                            Text("ON SALE")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    if let itemCode = lineItem.itemCode, !itemCode.isEmpty {
                        Text(itemCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if lineItem.quantity > 1 {
                        Text("×\(lineItem.quantity)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.costcoBlue)
                    }
                    
                    if let category = lineItem.category, !category.isEmpty, category != "Other" {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.costcoRed.opacity(0.1))
                            .foregroundColor(.costcoRed)
                            .cornerRadius(4)
                    }
                }
                
                // Show savings amount if on sale
                if isOnSale && lineItem.instantSavings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                        Text("You saved \(formatCurrency(lineItem.instantSavings))")
                            .font(.caption)
                            .fontWeight(.semibold)
                        // Show original price (which is lineItem.price on Costco receipts)
                        Text("(was \(formatCurrency(lineItem.price)))")
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .foregroundColor(.green)
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Price - show sale price if on sale, otherwise regular price
            VStack(alignment: .trailing, spacing: 2) {
                if isOnSale && lineItem.instantSavings > 0 {
                    // Show the discounted sale price
                    Text(formatCurrency(salePrice))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    // Show original price struck through
                    Text(formatCurrency(lineItem.price))
                        .font(.caption)
                        .strikethrough()
                        .foregroundColor(.secondary)
                } else {
                    // Regular price (not on sale)
                    Text(formatCurrency(lineItem.price))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, isOnSale ? 12 : 16)
        .padding(.vertical, 10)
        .background(isOnSale ? Color.green.opacity(0.08) : (isEven ? Color(.systemBackground) : Color(.systemGray6).opacity(0.5)))
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Compact Totals Section

struct CompactTotalsSection: View {
    let receipt: Receipt
    
    private var totalSavings: Double {
        receipt.lineItemsArray.reduce(0) { $0 + $1.instantSavings }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.costcoRed)
                .frame(height: 3)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(receipt.total))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.costcoRed)
                }
                
                Spacer()
                
                // Breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Subtotal:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(receipt.subtotal))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Text("Tax:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(receipt.tax))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Compact PDF Section

struct CompactPDFSection: View {
    let receipt: Receipt
    @Binding var showingPDFViewer: Bool
    
    var body: some View {
        Button(action: { showingPDFViewer = true }) {
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.title3)
                    .foregroundColor(.costcoRed)
                
                Text("View Original Receipt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }
}

// MARK: - Compact Action Buttons

struct CompactActionButtons: View {
    @Binding var showingEditSheet: Bool
    @Binding var showingShareSheet: Bool
    @Binding var showingDeleteAlert: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Edit button
            Button(action: { showingEditSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.costcoRed)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Share button
            Button(action: { showingShareSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.costcoBlue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Delete button (icon only)
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(10)
            }
        }
        .padding(16)
    }
}

// MARK: - Supporting Views

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PDFViewerView: View {
    let pdfData: Data?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if let pdfData = pdfData, let pdfDocument = PDFDocument(data: pdfData) {
                    PDFKitView(document: pdfDocument)
                } else {
                    Text("Unable to load PDF")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Receipt PDF")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

#Preview {
    NavigationView {
        ReceiptDetailView(receipt: PersistenceController.preview.container.viewContext.registeredObjects.first(where: { $0 is Receipt }) as! Receipt)
    }
    .environmentObject(ReceiptStore())
    .environmentObject(ThemeManager())
}
