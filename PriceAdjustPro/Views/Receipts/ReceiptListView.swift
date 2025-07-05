import SwiftUI
import CoreData

struct ReceiptListView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddReceipt = false
    @State private var selectedSortOption: SortOption = .dateNewest
    @State private var searchText = ""
    @State private var showingSettings = false
    
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
                                ZStack {
                                    ReceiptRowView(receipt: receipt)
                                    NavigationLink("", destination: DetailViewWrapper(receipt: receipt))
                                        .opacity(0)
                                }
                            }
                            .onDelete(perform: receiptStore.deleteReceipts)
                            .listRowBackground(themeManager.listRowBackgroundColor)
                        }
                        .background(Color.clear)
                        .onAppear {
                            // Remove default list background for iOS 15 compatibility
                            UITableView.appearance().backgroundColor = UIColor.clear
                        }
                    .refreshable {
                        receiptStore.syncWithServer()
                    }
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
            .navigationBarItems(
                leading: Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(themeManager.accentColor)
                },
                trailing: Button(action: {
                    showingAddReceipt = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(themeManager.accentColor)
                }
            )
            .searchable(text: $searchText)
            .toolbar {
                EditButton()
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
    
    @ViewBuilder
    private func sortButton(_ title: String, _ option: SortOption) -> some View {
        Button(title) {
            selectedSortOption = option
            sortReceipts()
        }
    }
}

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
                            Text("Instant Savings:")
                                .foregroundColor(themeManager.successColor)
                            Spacer()
                            Text("-$10.00") // This should come from API data
                                .foregroundColor(themeManager.successColor)
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
    
    var body: some View {
        let backgroundColor = themeManager.listRowBackgroundColor
        VStack(spacing: 0) {
            HStack {
                Text(lineItem.itemCode ?? "")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 80, alignment: .leading)
                
                Text(lineItem.name ?? "Unknown Item")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(formatCurrency(lineItem.price))
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 60, alignment: .trailing)
                
                Text("\(lineItem.quantity)")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 60, alignment: .center)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(lineItem.price * Double(lineItem.quantity)))
                        .font(.caption)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    // Show sale info if applicable (placeholder for now)
                    if lineItem.itemCode == "381" { // UBER FY24 items from your data
                        Text("🟢 On Sale: $5.00")
                            .font(.caption2)
                            .foregroundColor(themeManager.successColor)
                        Text("Was: $79.99")
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .strikethrough()
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(backgroundColor)
            
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