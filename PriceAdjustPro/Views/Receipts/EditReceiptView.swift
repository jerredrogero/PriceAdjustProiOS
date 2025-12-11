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
    @Published var onSale: Bool
    @Published var instantSavings: String
    @Published var originalPrice: String
    @Published var isExpanded: Bool = false
    
    init(lineItem: LineItem) {
        self.id = lineItem.id ?? UUID()
        self.originalLineItem = lineItem
        self.itemCode = lineItem.itemCode ?? ""
        self.description = lineItem.name ?? ""
        self.price = String(format: "%.2f", lineItem.price)
        self.quantity = String(lineItem.quantity)
        self.totalPrice = String(format: "%.2f", lineItem.price * Double(lineItem.quantity))
        self.onSale = lineItem.onSale
        self.instantSavings = String(format: "%.2f", lineItem.instantSavings)
        let original = lineItem.originalPrice > 0 ? lineItem.originalPrice : lineItem.price
        self.originalPrice = String(format: "%.2f", original)
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
    @State private var hasUnsavedChanges = false
    
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with quick info
                        HeaderCard()
                        
                        // Store Information Card
                        StoreInfoCard()
                        
                        // Date & Time Card
                        DateTimeCard()
                        
                        // Financial Summary Card
                        FinancialSummaryCard()
                        
                        // Line Items Card
                        LineItemsCard()
                        
                        // Notes Card
                        NotesCard()
                        
                        // Save Button
                        SaveButtonSection()
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
                
                if isLoading {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // TODO: Show unsaved changes alert
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.accentColor)
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
    
    // MARK: - Header Card
    @ViewBuilder
    private func HeaderCard() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receipt Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Last updated: \(formatDate(receipt.updatedAt ?? Date()))")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(total)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.successColor)
                    
                    Text("\(editableLineItems.count) items")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Store Information Card
    @ViewBuilder
    private func StoreInfoCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(themeManager.accentColor)
                
                Text("Store Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(spacing: 12) {
                CustomTextField(
                    title: "Store Name",
                    text: $storeName,
                    placeholder: "Enter store name",
                    icon: "storefront",
                    onChange: { hasUnsavedChanges = true }
                )
                
                CustomTextField(
                    title: "Store Location", 
                    text: $storeLocation,
                    placeholder: "Enter store location",
                    icon: "location",
                    onChange: { hasUnsavedChanges = true }
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .frame(width: 20)
                        
                        Text("Receipt Number")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Text(receiptNumber.isEmpty ? "No receipt number" : receiptNumber)
                        .font(.body)
                        .foregroundColor(themeManager.secondaryTextColor)
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
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Date & Time Card
    @ViewBuilder
    private func DateTimeCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.accentColor)
                
                Text("Date & Time")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            DatePicker(
                "Purchase Date", 
                selection: $date, 
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .foregroundColor(themeManager.primaryTextColor)
            .onChange(of: date) { _ in hasUnsavedChanges = true }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Financial Summary Card
    @ViewBuilder
    private func FinancialSummaryCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(themeManager.accentColor)
                
                Text("Financial Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(spacing: 12) {
                CurrencyField(
                    title: "Subtotal",
                    value: $subtotal,
                    icon: "minus.circle",
                    onChange: { hasUnsavedChanges = true }
                )
                
                CurrencyField(
                    title: "Tax",
                    value: $tax,
                    icon: "percent",
                    onChange: { 
                        hasUnsavedChanges = true
                        updateTotalFromSubtotalAndTax()
                    }
                )
                
                Divider()
                    .background(themeManager.secondaryTextColor.opacity(0.3))
                
                HStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeManager.successColor)
                            .frame(width: 20)
                        
                        Text("Total")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    Text("$\(total)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.successColor)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Line Items Card
    @ViewBuilder
    private func LineItemsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(themeManager.accentColor)
                
                Text("Line Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                Button(action: {
                    // TODO: Add functionality to add new line item
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(themeManager.accentColor)
                        .font(.title2)
                }
            }
            
            if editableLineItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text("No items found")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(editableLineItems.indices, id: \.self) { index in
                        ModernLineItemRow(
                            editableLineItem: editableLineItems[index],
                            onUpdate: {
                                editableLineItems[index].updateTotalPrice()
                                updateReceiptTotals()
                                hasUnsavedChanges = true
                            },
                            onDelete: {
                                editableLineItems.remove(at: index)
                                updateReceiptTotals()
                                hasUnsavedChanges = true
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Notes Card
    @ViewBuilder
    private func NotesCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(themeManager.accentColor)
                
                Text("Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add notes about this receipt...")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                if #available(iOS 16.0, *) {
                    TextEditor(text: $notes)
                        .foregroundColor(themeManager.primaryTextColor)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.backgroundColor.opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: notes) { _ in hasUnsavedChanges = true }
                } else {
                    // iOS 15 fallback - use TextField for single line or custom approach
                    TextEditor(text: $notes)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.backgroundColor.opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: notes) { _ in hasUnsavedChanges = true }
                        .onAppear {
                            UITextView.appearance().backgroundColor = .clear
                        }
                }
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Save Button Section
    @ViewBuilder
    private func SaveButtonSection() -> some View {
        Button(action: saveChanges) {
            HStack {
                if !isLoading {
                    Image(systemName: "checkmark.circle.fill")
                }
                
                Text(isLoading ? "Saving..." : "Save Changes")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(radius: 4)
        }
        .disabled(isLoading || !hasUnsavedChanges)
        .opacity((isLoading || !hasUnsavedChanges) ? 0.6 : 1.0)
    }
    
    // MARK: - Loading Overlay
    @ViewBuilder
    private func LoadingOverlay() -> some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .tint(themeManager.accentColor)
            
            Text("Updating Receipt...")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.top)
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    // MARK: - Helper Functions
    private func updateTotalFromSubtotalAndTax() {
        let subtotalValue = Double(subtotal) ?? 0.0
        let taxValue = Double(tax) ?? 0.0
        total = String(format: "%.2f", subtotalValue + taxValue)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                    hasUnsavedChanges = false
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
        
        // Create new line items from editable items (preserve order)
        for (index, editableItem) in editableLineItems.enumerated() {
            let lineItem = LineItem(context: context)
            lineItem.id = editableItem.id
            lineItem.itemCode = editableItem.itemCode.isEmpty ? nil : editableItem.itemCode
            lineItem.name = editableItem.description.isEmpty ? nil : editableItem.description
            lineItem.price = Double(editableItem.price) ?? 0.0
            lineItem.quantity = Int32(editableItem.quantity) ?? 1
            lineItem.category = nil
            lineItem.orderIndex = Int32(index)
            lineItem.onSale = editableItem.onSale || (Double(editableItem.instantSavings) ?? 0) > 0
            lineItem.instantSavings = Double(editableItem.instantSavings) ?? 0.0
            lineItem.originalPrice = Double(editableItem.originalPrice) ?? lineItem.price
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

// MARK: - Custom Components

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let onChange: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            TextField(placeholder, text: $text)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.backgroundColor.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: text) { _ in onChange() }
        }
    }
}

struct CurrencyField: View {
    let title: String
    @Binding var value: String
    let icon: String
    let onChange: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                HStack {
                    Text("$")
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    TextField("0.00", text: $value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 80)
                        .onChange(of: value) { newValue in
                            // Format currency input
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                value = filtered
                            }
                            onChange()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeManager.backgroundColor.opacity(0.5))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

struct ModernLineItemRow: View {
    @ObservedObject var editableLineItem: EditableLineItem
    let onUpdate: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Summary Row - Always Visible
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(editableLineItem.description.isEmpty ? "Unnamed Item" : editableLineItem.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(2)
                    
                    if !editableLineItem.itemCode.isEmpty {
                        Text("Code: \(editableLineItem.itemCode)")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(editableLineItem.totalPrice)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.successColor)
                    
                    Text("Qty: \(editableLineItem.quantity)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Button(action: {
                    editableLineItem.isExpanded.toggle()
                }) {
                    Image(systemName: editableLineItem.isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(themeManager.accentColor)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onTapGesture {
                editableLineItem.isExpanded.toggle()
            }
            
            // Expanded Edit Section
            if editableLineItem.isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(themeManager.secondaryTextColor.opacity(0.3))
                    
                    // Item Details
                    VStack(spacing: 12) {
                        // Item Code
                        HStack {
                            Text("Item Code")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Enter item code", text: $editableLineItem.itemCode)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(themeManager.backgroundColor.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: editableLineItem.itemCode) { _ in onUpdate() }
                        }
                        
                        // Description
                        HStack {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Enter description", text: $editableLineItem.description)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(themeManager.backgroundColor.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: editableLineItem.description) { _ in onUpdate() }
                        }
                        
                        // Price and Quantity
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Price")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                
                                HStack {
                                    Text("$")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    TextField("0.00", text: $editableLineItem.price)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .onChange(of: editableLineItem.price) { _ in 
                                            editableLineItem.updateTotalPrice()
                                            onUpdate() 
                                        }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(themeManager.backgroundColor.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quantity")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                
                                TextField("1", text: $editableLineItem.quantity)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(themeManager.backgroundColor.opacity(0.5))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: editableLineItem.quantity) { _ in 
                                        editableLineItem.updateTotalPrice()
                                        onUpdate() 
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                
                                Text("$\(editableLineItem.totalPrice)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.successColor)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // Delete Button
                    Button(action: onDelete) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Item")
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.errorColor)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(themeManager.backgroundColor.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.secondaryTextColor.opacity(0.2), lineWidth: 1)
        )
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