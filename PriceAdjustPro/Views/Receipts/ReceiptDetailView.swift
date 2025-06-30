import SwiftUI
import PDFKit

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingPDFViewer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                ReceiptHeaderCard(receipt: receipt)
                
                // Line Items
                LineItemsSection(receipt: receipt)
                
                // Totals Section
                TotalsSection(receipt: receipt)
                
                // PDF Preview (if available)
                if receipt.pdfData != nil {
                    PDFPreviewSection(receipt: receipt, showingPDFViewer: $showingPDFViewer)
                }
                
                // Action Buttons
                ActionButtonsSection(
                    showingEditSheet: $showingEditSheet,
                    showingShareSheet: $showingShareSheet,
                    showingDeleteAlert: $showingDeleteAlert
                )
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
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
        
        // Add text summary
        let summary = createTextSummary()
        items.append(summary)
        
        // Add PDF if available
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

struct ReceiptHeaderCard: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(spacing: 15) {
            // Store Info
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(.costcoBlue)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(receipt.storeName ?? "Unknown Store")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let location = receipt.storeLocation {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status Badge
                if let status = receipt.processingStatus {
                    Text(status.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor(for: status))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Receipt Info
            VStack(spacing: 10) {
                InfoRow(label: "Date", value: receipt.formattedDate)
                
                if let receiptNumber = receipt.receiptNumber {
                    InfoRow(label: "Receipt #", value: receiptNumber)
                }
                
                InfoRow(label: "Items", value: "\(receipt.lineItemsArray.count)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "completed":
            return .green
        case "processing":
            return .orange
        case "failed":
            return .red
        default:
            return .gray
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct LineItemsSection: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Items")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 10) {
                ForEach(receipt.lineItemsArray, id: \.objectID) { lineItem in
                    LineItemRow(lineItem: lineItem)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LineItemRow: View {
    let lineItem: LineItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(lineItem.name ?? "Unknown Item")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    if let itemCode = lineItem.itemCode {
                        Text("Code: \(itemCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let category = lineItem.category {
                        Text("• \(category)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text(formatCurrency(lineItem.price))
                    .font(.body)
                    .fontWeight(.semibold)
                
                if lineItem.quantity > 1 {
                    Text("Qty: \(lineItem.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct TotalsSection: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Summary")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                TotalRow(label: "Subtotal", amount: receipt.subtotal, isTotal: false)
                TotalRow(label: "Tax", amount: receipt.tax, isTotal: false)
                
                Divider()
                
                TotalRow(label: "Total", amount: receipt.total, isTotal: true)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct TotalRow: View {
    let label: String
    let amount: Double
    let isTotal: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .bold : .medium)
            
            Spacer()
            
            Text(formatCurrency(amount))
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .bold : .semibold)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct PDFPreviewSection: View {
    let receipt: Receipt
    @Binding var showingPDFViewer: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Receipt PDF")
                .font(.title3)
                .fontWeight(.bold)
            
            Button(action: {
                showingPDFViewer = true
            }) {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.costcoRed)
                    
                    VStack(alignment: .leading) {
                        Text("View Original Receipt")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("PDF Document")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ActionButtonsSection: View {
    @Binding var showingEditSheet: Bool
    @Binding var showingShareSheet: Bool
    @Binding var showingDeleteAlert: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            // Primary Actions
            HStack(spacing: 15) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.costcoBlue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            // Delete Button
            Button(action: {
                showingDeleteAlert = true
            }) {
                Label("Delete Receipt", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

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