import SwiftUI
import CoreData

struct ReceiptListView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddReceipt = false
    @State private var selectedSortOption: SortOption = .dateNewest
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var selectedReceiptForNavigation: Receipt?
    @State private var showReceiptDetail = false
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case totalHighest = "Total (Highest)"
        case totalLowest = "Total (Lowest)"
        case storeName = "Store Name"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Filter and Sort Controls
                    HStack {
                    // Sort Picker
                    Menu {
                        sortButton("Date (Newest)", .dateNewest)
                        sortButton("Date (Oldest)", .dateOldest)
                        sortButton("Total (Highest)", .totalHighest)
                        sortButton("Total (Lowest)", .totalLowest)
                        sortButton("Store Name", .storeName)
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .foregroundColor(themeManager.accentColor)
                    }
                    
                    Spacer()
                    
                    // Sync Button
                    Button(action: {
                        receiptStore.syncWithServer()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync")
                        }
                        .foregroundColor(themeManager.accentColor)
                    }
                    .disabled(receiptStore.isLoading)
                }
                .padding(.horizontal)
                
                // Receipts List
                if receiptStore.receipts.isEmpty {
                    if searchText.isEmpty {
                        EmptyStateView()
                    } else {
                        SearchEmptyStateView(searchText: searchText)
                    }
                } else {
                    List {
                        ForEach(sortedReceipts, id: \.objectID) { receipt in
                            Button {
                                selectedReceiptForNavigation = receipt
                                showReceiptDetail = true
                            } label: {
                                ReceiptCardView(receipt: receipt)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(themeManager.backgroundColor)
                        }
                        .onDelete(perform: deleteReceipts)
                    }
                    .listStyle(.plain)
                    .background(themeManager.backgroundColor)
                    .refreshable { receiptStore.syncWithServer() }
                }
                
                // Error Message
                if let errorMessage = receiptStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(themeManager.errorColor)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddReceipt = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .onAppear {
                receiptStore.loadReceipts()
                searchText = receiptStore.searchText
            }
            .onChange(of: searchText) { newValue in
                receiptStore.searchText = newValue
            }
            .overlay(
                Group {
                    if receiptStore.isLoading {
                        LoadingView()
                    }
                }
            )
            .background(
                NavigationLink(
                    destination: Group {
                        if let receipt = selectedReceiptForNavigation {
                            ReceiptDetailView(receipt: receipt)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $showReceiptDetail
                ) {
                    EmptyView()
                }
                .hidden()
            )
            }
        }
        .sheet(isPresented: $showingAddReceipt) {
            AddReceiptView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private var sortedReceipts: [Receipt] {
        let receiptsToSort = receiptStore.receipts
        
        switch selectedSortOption {
        case .dateNewest:
            return receiptsToSort.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        case .dateOldest:
            return receiptsToSort.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        case .totalHighest:
            return receiptsToSort.sorted { $0.total > $1.total }
        case .totalLowest:
            return receiptsToSort.sorted { $0.total < $1.total }
        case .storeName:
            return receiptsToSort.sorted { ($0.storeName ?? "") < ($1.storeName ?? "") }
        }
    }
    
    private func sortReceipts() {
        // The sorting is handled by the computed property
        // This function can be used to trigger any additional side effects if needed
        // For now, it just needs to exist for the Menu buttons
    }
    
    private func deleteReceipts(at offsets: IndexSet) {
        // Offsets are for the *sorted* list; delete the corresponding receipts.
        let receiptsToDelete = offsets.map { sortedReceipts[$0] }
        for receipt in receiptsToDelete {
            receiptStore.deleteReceipt(receipt)
        }
    }
    
    @ViewBuilder
    private func sortButton(_ title: String, _ option: SortOption) -> some View {
        Button(title) {
            selectedSortOption = option
            sortReceipts()
        }
    }
}

struct ReceiptCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let receipt: Receipt
    
    private let accentColor: Color = .costcoRed
    
    // Check if receipt has any sale items (either onSale flag or has savings)
    private var hasSaleItems: Bool {
        receipt.lineItemsArray.contains { $0.onSale || $0.instantSavings > 0 }
    }
    
    // Calculate total savings for this receipt
    private var totalSavings: Double {
        receipt.lineItemsArray.reduce(0) { $0 + $1.instantSavings }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Colored accent bar on the left
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)
            
            // Main content
            HStack(spacing: 16) {
                // Receipt icon with colored background
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "receipt")
                        .font(.system(size: 22))
                        .foregroundColor(accentColor)
                }
                
                // Receipt details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(receipt.storeName ?? "Unknown Store")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                        
                        // Sale indicator badge
                        if hasSaleItems {
                            Text("SALE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text(receipt.date ?? Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        // Items count
                        HStack(spacing: 4) {
                            Image(systemName: "cart")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("\(receipt.lineItemsArray.count) items")
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    
                    // Show savings if any
                    if totalSavings > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                            Text("Saved \(formatCurrency(totalSavings))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                    } else if let receiptNumber = receipt.receiptNumber {
                        Text("#\(receiptNumber)")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Total amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", receipt.total))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(accentColor)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                }
            }
            .padding(16)
        }
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// Keep the old ReceiptRowView for backwards compatibility if needed elsewhere
struct ReceiptRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(receipt.storeName ?? "Unknown Store")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            HStack {
                Text(receipt.date ?? Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Spacer()
                
                Text(String(format: "$%.2f", receipt.total))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            if let receiptNumber = receipt.receiptNumber {
                Text("Receipt #: \(receiptNumber)")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.secondaryTextColor)
            
            TextField("Search receipts...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    HStack {
                        Spacer()
                        if !text.isEmpty {
                            Button(action: {
                                text = ""
                                // Hide keyboard
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("No Receipts Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("Tap the + button to add your first receipt")
                .font(.body)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button("Add Receipt") {
                // This could trigger the add receipt sheet
            }
            .padding()
            .background(themeManager.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor)
    }
}

struct SearchEmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("No receipts match '\(searchText)'")
                .font(.body)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Text("Try searching for store names, receipt numbers, or item names")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor)
    }
}

struct LoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentColor))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            .padding(30)
            .background(themeManager.cardBackgroundColor.opacity(0.9))
            .cornerRadius(15)
        }
    }
}

struct DetailViewWrapper: View {
    let receipt: Receipt
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingEditSheet = false
    
    var body: some View {
        ZStack {
            // Theme background
            themeManager.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(receipt.storeName ?? "Unknown Store")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("Transaction #: \(receipt.receiptNumber ?? "Unknown")")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        if let date = receipt.date {
                            Text("Date: \(formatDate(date))")
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(themeManager.cardBackgroundColor)
                    
                    // Line Items Table
                    VStack(spacing: 0) {
                        // Table Header
                        HStack {
                            Text("Item Code")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 80, alignment: .leading)
                            
                            Text("Description")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Price")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 60, alignment: .trailing)
                            
                            Text("Quantity")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 60, alignment: .center)
                            
                            Text("Total")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        
                        // Line Items
                        ForEach(receipt.lineItemsArray, id: \.objectID) { lineItem in
                            LineItemDetailRow(lineItem: lineItem)
                        }
                    }
                    
                    // Summary Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Subtotal:")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Text(formatCurrency(receipt.subtotal))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        HStack {
                            Text("Tax:")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Text(formatCurrency(receipt.tax))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        Divider()
                            .background(themeManager.secondaryTextColor)
                        
                        HStack {
                            Text("Total:")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Text(formatCurrency(receipt.total))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // Notes Section (if notes exist)
                    if let notes = receipt.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(themeManager.accentColor)
                                
                                Text("Notes")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(themeManager.backgroundColor.opacity(0.5))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding()
                        .background(themeManager.cardBackgroundColor)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                }
                .padding(.top, 100) // Add padding to account for custom navigation bar
            }
        }
        .navigationBarHidden(true)
        .overlay(
            // Custom Navigation Bar
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Receipts")
                        }
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Receipt")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.accentColor)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(themeManager.backgroundColor)
                
                Spacer()
            }
        )
        .sheet(isPresented: $showingEditSheet) {
            EditReceiptView(receipt: receipt)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

struct LineItemDetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let lineItem: LineItem
    
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
        let backgroundColor = themeManager.listRowBackgroundColor
        VStack(spacing: 0) {
            HStack {
                Text(lineItem.itemCode ?? "")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 80, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(lineItem.name ?? "Unknown Item")
                        .font(.caption)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    if isOnSale {
                        Text("SALE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Show sale price if on sale, otherwise regular price
                if isOnSale && lineItem.instantSavings > 0 {
                    Text(formatCurrency(salePrice))
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text(formatCurrency(lineItem.price))
                        .font(.caption)
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 60, alignment: .trailing)
                }
                
                Text("\(lineItem.quantity)")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 60, alignment: .center)
                
                VStack(alignment: .trailing, spacing: 2) {
                    // Show sale total or regular total
                    if isOnSale && lineItem.instantSavings > 0 {
                        Text(formatCurrency(salePrice * Double(lineItem.quantity)))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text(formatCurrency(lineItem.price * Double(lineItem.quantity)))
                            .font(.caption)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    // Show sale info if applicable
                    if isOnSale && lineItem.instantSavings > 0 {
                        Text("Saved: \(formatCurrency(lineItem.instantSavings))")
                            .font(.caption2)
                            .foregroundColor(.green)
                        // Show original price (lineItem.price is the original on Costco receipts)
                        Text("Was: \(formatCurrency(lineItem.price))")
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .strikethrough()
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isOnSale ? Color.green.opacity(0.08) : backgroundColor)
            
            Divider()
                .background(themeManager.secondaryTextColor.opacity(0.3))
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    ReceiptListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ReceiptStore())
        .environmentObject(ThemeManager())
} 