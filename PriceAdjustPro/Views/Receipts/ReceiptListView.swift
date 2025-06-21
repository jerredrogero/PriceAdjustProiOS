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
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Filter and Sort Controls
                    HStack {
                    // Sort Picker
                    Menu {
                        Button("Date (Newest)") {
                            selectedSortOption = .dateNewest
                            sortReceipts()
                        }
                        Button("Date (Oldest)") {
                            selectedSortOption = .dateOldest
                            sortReceipts()
                        }
                        Button("Total (Highest)") {
                            selectedSortOption = .totalHighest
                            sortReceipts()
                        }
                        Button("Total (Lowest)") {
                            selectedSortOption = .totalLowest
                            sortReceipts()
                        }
                        Button("Store Name") {
                            selectedSortOption = .storeName
                            sortReceipts()
                        }
                                            } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                                .foregroundColor(.red)
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
                        .foregroundColor(.red)
                    }
                    .disabled(receiptStore.isLoading)
                }
                .padding(.horizontal)
                
                // Receipts List
                if receiptStore.receipts.isEmpty {
                    EmptyStateView()
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
                            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
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
                        .foregroundColor(.red)
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
                        .foregroundColor(.red)
                },
                trailing: Button(action: {
                    showingAddReceipt = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.red)
                }
            )
            .searchable(text: $searchText)
            .toolbar {
                EditButton()
            }
            .onAppear {
                receiptStore.loadReceipts()
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
        switch selectedSortOption {
        case .dateNewest:
            return receiptStore.receipts.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        case .dateOldest:
            return receiptStore.receipts.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        case .totalHighest:
            return receiptStore.receipts.sorted { $0.total > $1.total }
        case .totalLowest:
            return receiptStore.receipts.sorted { $0.total < $1.total }
        case .storeName:
            return receiptStore.receipts.sorted { ($0.storeName ?? "") < ($1.storeName ?? "") }
        }
    }
    
    private func sortReceipts() {
        // Trigger view update by modifying a @Published property
        receiptStore.receipts = sortedReceipts
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(receipt.storeName ?? "Unknown Store")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Text(receipt.date ?? Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(String(format: "$%.2f", receipt.total))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            if let receiptNumber = receipt.receiptNumber {
                Text("Receipt #: \(receiptNumber)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search receipts...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Receipts Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Tap the + button to add your first receipt")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Add Receipt") {
                // This could trigger the add receipt sheet
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)
        }
    }
}

struct DetailViewWrapper: View {
    let receipt: Receipt
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditSheet = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(receipt.storeName ?? "Unknown Store")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Transaction #: \(receipt.receiptNumber ?? "Unknown")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if let date = receipt.date {
                            Text("Date: \(formatDate(date))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    
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
                        .background(Color.red)
                        
                        // Line Items
                        ForEach(receipt.lineItemsArray, id: \.objectID) { lineItem in
                            LineItemDetailRow(lineItem: lineItem)
                        }
                    }
                    
                    // Summary Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Subtotal:")
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatCurrency(receipt.subtotal))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Instant Savings:")
                                .foregroundColor(.green)
                            Spacer()
                            Text("-$10.00") // This should come from API data
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Tax:")
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatCurrency(receipt.tax))
                                .foregroundColor(.white)
                        }
                        
                        Divider()
                            .background(Color.gray)
                        
                        HStack {
                            Text("Total:")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatCurrency(receipt.total))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
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
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 1)
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
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black)
                
                Spacer()
            }
        )
        .sheet(isPresented: $showingEditSheet) {
            Text("Edit Receipt - Coming Soon")
                .padding()
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
    let lineItem: LineItem
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(lineItem.itemCode ?? "")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
                
                Text(lineItem.name ?? "Unknown Item")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(formatCurrency(lineItem.price))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .trailing)
                
                Text("\(lineItem.quantity)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .center)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(lineItem.price * Double(lineItem.quantity)))
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    // Show sale info if applicable (placeholder for now)
                    if lineItem.itemCode == "381" { // UBER FY24 items from your data
                        Text("🟢 On Sale: $5.00")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Was: $79.99")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .strikethrough()
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            
            Divider()
                .background(Color.gray.opacity(0.3))
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
} 