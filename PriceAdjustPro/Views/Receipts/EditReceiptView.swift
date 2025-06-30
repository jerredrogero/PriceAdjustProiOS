import SwiftUI
import CoreData


// MARK: - Editable Line Item Model
class EditableLineItem: ObservableObject, Identifiable {
    let id: UUID
    let originalLineItem: LineItem
    @Published var itemCode: String
    @Published var description: String
    @Published var price: String
    @Published var quantity: String
    @Published var totalPrice: String
    
    init(lineItem: LineItem) {
        self.id = lineItem.id ?? UUID()
        self.originalLineItem = lineItem
        self.itemCode = lineItem.itemCode ?? ""
        self.description = lineItem.name ?? ""
        self.price = String(format: "%.2f", lineItem.price)
        self.quantity = String(lineItem.quantity)
        self.totalPrice = String(format: "%.2f", lineItem.price * Double(lineItem.quantity))
    }
    
    func updateTotalPrice() {
        let priceValue = Double(price) ?? 0.0
        let quantityValue = Double(quantity) ?? 0.0
        totalPrice = String(format: "%.2f", priceValue * quantityValue)
    }
}

struct EditReceiptView: View {
    let receipt: Receipt
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var storeName: String
    @State private var receiptNumber: String
    @State private var storeLocation: String
    @State private var date: Date
    @State private var subtotal: String
    @State private var tax: String
    @State private var total: String
    @State private var notes: String
    @State private var editableLineItems: [EditableLineItem] = []
    
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    init(receipt: Receipt) {
        self.receipt = receipt
        _storeName = State(initialValue: receipt.storeName ?? "")
        _receiptNumber = State(initialValue: receipt.receiptNumber ?? "")
        _storeLocation = State(initialValue: receipt.storeLocation ?? "")
        _date = State(initialValue: receipt.date ?? Date())
        _subtotal = State(initialValue: String(format: "%.2f", receipt.subtotal))
        _tax = State(initialValue: String(format: "%.2f", receipt.tax))
        _total = State(initialValue: String(format: "%.2f", receipt.total))
        _notes = State(initialValue: receipt.notes ?? "")
        _editableLineItems = State(initialValue: receipt.lineItemsArray.map { EditableLineItem(lineItem: $0) })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                Form {
                    Section("Store Information") {
                        TextField("Store Name", text: $storeName)
                        TextField("Store Location", text: $storeLocation)
                        TextField("Receipt Number", text: $receiptNumber)
                            .disabled(true) // Receipt number shouldn't be editable
                            .foregroundColor(.gray)
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    Section("Date & Time") {
                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    Section("Totals") {
                        HStack {
                            Text("Subtotal")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            TextField("0.00", text: $subtotal)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        HStack {
                            Text("Tax")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            TextField("0.00", text: $tax)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        HStack {
                            Text("Total")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            TextField("0.00", text: $total)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    Section("Notes") {
                        TextField("Add notes about this receipt...", text: $notes)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                    
                    Section("Line Items") {
                        ForEach(editableLineItems.indices, id: \.self) { index in
                            EditableLineItemRow(
                                editableLineItem: editableLineItems[index],
                                themeManager: themeManager,
                                onUpdate: {
                                    editableLineItems[index].updateTotalPrice()
                                    updateReceiptTotals()
                                }
                            )
                        }
                    }
                    .listRowBackground(themeManager.cardBackgroundColor)
                }
                .foregroundColor(themeManager.primaryTextColor)
                
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.costcoRed)
                        
                        Text("Updating Receipt...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.costcoRed)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.costcoRed)
                    .disabled(isLoading)
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
    
    private func saveChanges() {
        AppLogger.user("Save receipt changes")
        
        // Update local receipt first
        receipt.storeName = storeName.isEmpty ? nil : storeName
        receipt.storeLocation = storeLocation.isEmpty ? nil : storeLocation
        receipt.date = date
        receipt.subtotal = Double(subtotal) ?? 0.0
        receipt.tax = Double(tax) ?? 0.0
        receipt.total = Double(total) ?? 0.0
        receipt.notes = notes.isEmpty ? nil : notes
        
        // Update line items locally
        updateLocalLineItems()
        
        isLoading = true
        
        // Update via API
        receiptStore.updateReceiptWithAPI(receipt) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    alertTitle = "Success"
                    alertMessage = "Receipt updated successfully!"
                    showingAlert = true
                    
                case .failure(let error):
                    alertTitle = "Error"
                    alertMessage = "Failed to update receipt: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func updateReceiptTotals() {
        let newSubtotal = editableLineItems.reduce(0.0) { sum, item in
            sum + (Double(item.totalPrice) ?? 0.0)
        }
        subtotal = String(format: "%.2f", newSubtotal)
        
        let taxValue = Double(tax) ?? 0.0
        let newTotal = newSubtotal + taxValue
        total = String(format: "%.2f", newTotal)
    }
    
    private func updateLocalLineItems() {
        guard let context = receipt.managedObjectContext else { return }
        
        // Remove all existing line items
        let existingLineItems = receipt.lineItemsArray
        for lineItem in existingLineItems {
            context.delete(lineItem)
        }
        
        // Create new line items from editable items
        for editableItem in editableLineItems {
            let lineItem = LineItem(context: context)
            lineItem.id = editableItem.id
            lineItem.itemCode = editableItem.itemCode.isEmpty ? nil : editableItem.itemCode
            lineItem.name = editableItem.description.isEmpty ? nil : editableItem.description
            lineItem.price = Double(editableItem.price) ?? 0.0
            lineItem.quantity = Int32(editableItem.quantity) ?? 1
            lineItem.category = nil
            lineItem.receipt = receipt
        }
        
        // Save the context to persist changes
        do {
            try context.save()
        } catch {
            AppLogger.logError(error, context: "Edit receipt line items update")
        }
    }
}

struct EditableLineItemRow: View {
    @ObservedObject var editableLineItem: EditableLineItem
    let themeManager: ThemeManager
    let onUpdate: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Item Code and Description
            VStack(spacing: 8) {
                HStack {
                    Text("Item Code")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Item Code", text: $editableLineItem.itemCode)
                        .foregroundColor(themeManager.primaryTextColor)
                        .onChange(of: editableLineItem.itemCode) { _ in onUpdate() }
                }
                
                HStack {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Description", text: $editableLineItem.description)
                        .foregroundColor(themeManager.primaryTextColor)
                        .onChange(of: editableLineItem.description) { _ in onUpdate() }
                }
            }
            
            // Price, Quantity, and Total
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Price")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    TextField("0.00", text: $editableLineItem.price)
                        .keyboardType(.decimalPad)
                        .foregroundColor(themeManager.primaryTextColor)
                        .onChange(of: editableLineItem.price) { _ in 
                            editableLineItem.updateTotalPrice()
                            onUpdate() 
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("Qty")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    TextField("1", text: $editableLineItem.quantity)
                        .keyboardType(.numberPad)
                        .foregroundColor(themeManager.primaryTextColor)
                        .onChange(of: editableLineItem.quantity) { _ in 
                            editableLineItem.updateTotalPrice()
                            onUpdate() 
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("$\(editableLineItem.totalPrice)")
                        .foregroundColor(themeManager.primaryTextColor)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let receipt = Receipt(context: context)
    receipt.id = UUID()
    receipt.storeName = "Costco Wholesale"
    receipt.storeLocation = "Mountain View, CA"
    receipt.date = Date()
    receipt.receiptNumber = "123456789"
    receipt.subtotal = 99.99
    receipt.tax = 8.25
    receipt.total = 108.24
    receipt.isProcessed = true
    receipt.processingStatus = "completed"
    receipt.createdAt = Date()
    receipt.updatedAt = Date()
    
    return NavigationView {
        EditReceiptView(receipt: receipt)
    }
    .environmentObject(ReceiptStore())
    .environmentObject(ThemeManager())
} 