import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

struct AddReceiptView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var accountService: AccountService
    @StateObject private var pdfService = PDFService.shared
    
    @State private var showingImagePicker = false
    @State private var showingPhotoLibrary = false
    @State private var showingDocumentPicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var selectedPDF: PDFDocument?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var uploadSuccessMessage: String?
    @State private var showingSuccessAlert = false

    
    var body: some View {
        NavigationView {
            mainContent
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.accentColor),
                    trailing: EmptyView()
                )
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedPDF: $selectedPDF)
        }
        .onChange(of: selectedImage) { newImage in
            print("📷 onChange triggered for selectedImage: \(newImage != nil ? "Image selected" : "Image cleared")")
            Task {
                await processImage()
            }
        }
        .onChange(of: selectedPDF) { newPDF in
            print("📄 onChange triggered for selectedPDF: \(newPDF != nil ? "PDF selected" : "PDF cleared")")
            Task {
                await processPDF()
            }
        }
        .alert("Upload Successful!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(uploadSuccessMessage ?? "Your receipt has been uploaded successfully.")
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Upload Limit Status (for free users)
                if accountService.isFreeUser {
                    uploadLimitStatusSection
                }
                
                // Header
                headerSection
                
                // Upload options or processing state
                if isProcessing {
                    processingSection
                } else if selectedImage != nil || selectedPDF != nil {
                    selectedContentPreview
                } else {
                    uploadOptionsSection
                }
                
                // Message section
                messageSection
                
                // Instructions
                instructionsSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(themeManager.backgroundColor)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Modern icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.accentColor.opacity(0.8),
                                themeManager.accentColor
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(radius: 8)
                
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Add Receipt")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("Scan or upload your receipt to track spending and find price adjustments")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }
    
    private var uploadOptionsSection: some View {
        VStack(spacing: 16) {
            // Camera option
            Button(action: {
                if accountService.checkReceiptUploadLimit() {
                    showingCamera = true
                }
            }) {
                ModernUploadOptionView(
                    icon: "camera.fill",
                    title: "Take Photo",
                    description: "Capture receipt with camera",
                    color: themeManager.accentColor,
                    isRecommended: true,
                    isDisabled: !accountService.canUploadReceipts
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!accountService.canUploadReceipts)
            
            // Photo Library option
            Button(action: {
                if accountService.checkReceiptUploadLimit() {
                    showingPhotoLibrary = true
                }
            }) {
                ModernUploadOptionView(
                    icon: "photo.on.rectangle",
                    title: "Choose from Photos",
                    description: "Select from photo library",
                    color: .costcoRed,
                    isDisabled: !accountService.canUploadReceipts
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!accountService.canUploadReceipts)
            
            // PDF/Document option (kept but de-emphasized)
            Button(action: {
                if accountService.checkReceiptUploadLimit() {
                    showingDocumentPicker = true
                }
            }) {
                ModernUploadOptionView(
                    icon: "doc.fill",
                    title: "Upload Document",
                    description: "Select PDF or document file",
                    color: .orange,
                    isDisabled: !accountService.canUploadReceipts
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!accountService.canUploadReceipts)
            
            // Limit reached message
            if !accountService.canUploadReceipts {
                VStack(spacing: 12) {
                    Text("Upload limit reached")
                        .font(.headline)
                        .foregroundColor(themeManager.errorColor)
                    
                    Text("Upgrade to Premium for unlimited receipt uploads")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                    
                    Button("Upgrade Now") {
                        if let url = URL(string: "https://priceadjustpro.com/subscription") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding()
                .background(themeManager.errorColor.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.errorColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private var processingSection: some View {
        if isProcessing {
            VStack(spacing: 20) {
                // Modern loading indicator
                ZStack {
                    Circle()
                        .stroke(themeManager.secondaryTextColor.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(themeManager.accentColor, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
                }
                
                VStack(spacing: 8) {
                    Text("Processing Receipt...")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Please wait while we extract the data")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                if pdfService.processingProgress > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: pdfService.processingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: themeManager.accentColor))
                            .frame(maxWidth: 200)
                        
                        Text("\(Int(pdfService.processingProgress * 100))% complete")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            .padding()
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(16)
            .shadow(radius: 4)
        }
    }
    
    @ViewBuilder
    private var messageSection: some View {
        if let errorMessage = errorMessage {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(themeManager.errorColor)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(themeManager.errorColor)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding()
            .background(themeManager.errorColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.errorColor.opacity(0.3), lineWidth: 1)
            )
        }
        
        if let successMessage = uploadSuccessMessage {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeManager.successColor)
                
                Text(successMessage)
                    .font(.subheadline)
                    .foregroundColor(themeManager.successColor)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding()
            .background(themeManager.successColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.successColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(themeManager.warningColor)
                
                Text("Tips for best results")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "sun.max", text: "Ensure the receipt is well-lit")
                TipRow(icon: "viewfinder", text: "Include the entire receipt in frame")
                TipRow(icon: "textformat", text: "Make sure all text is readable")
                TipRow(icon: "hand.raised", text: "Hold device steady when capturing")
            }
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Upload Limit Status Section
    
    private var uploadLimitStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload Limit")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(accountService.getReceiptLimitMessage())
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                if accountService.hasReachedReceiptLimit {
                    Button("Upgrade") {
                        if let url = URL(string: "https://priceadjustpro.com/subscription") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Progress bar
            if accountService.receiptLimit > 0 {
                ProgressView(value: accountService.receiptLimitProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: accountService.hasReachedReceiptLimit ? .red : themeManager.accentColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .padding(20)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Processing Functions
    
    private func processImage() async {
    guard let image = selectedImage else { return }
    
    await MainActor.run {
        isProcessing = true
        errorMessage = nil
        uploadSuccessMessage = nil
    }
    
    // Convert image to data
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        await MainActor.run {
            errorMessage = "Failed to process image"
            isProcessing = false
        }
        return
    }
    
    // Upload image to server for processing
    let fileName = "receipt_\(Date().timeIntervalSince1970).jpg"
    
    do {
        print("📤 Starting image upload: \(fileName)")
        try await receiptStore.uploadReceiptToServer(pdfData: imageData, fileName: fileName)
        
        await MainActor.run {
            isProcessing = false
            selectedImage = nil
            uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
            
            // Sync with server to get the new receipt, then show success
            Task {
                await findAndNavigateToLatestReceipt()
            }
        }
    } catch APIService.APIError.uploadSuccessButNoData {
        // This is actually a success case - server accepted upload but returned no parseable data
        print("✅ Image upload successful (server returned success but no data)")
        await MainActor.run {
            isProcessing = false
            selectedImage = nil
            uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
            
            // Sync with server to get the new receipt, then show success
            Task {
                await findAndNavigateToLatestReceipt()
            }
        }
    } catch APIService.APIError.networkError(let underlyingError) {
        // Check if the underlying error is actually uploadSuccessButNoData
        if let apiError = underlyingError as? APIService.APIError,
           case .uploadSuccessButNoData = apiError {
            print("✅ Image upload successful (wrapped success but no data)")
            await MainActor.run {
                isProcessing = false
                selectedImage = nil
                uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                
                // Sync with server to get the new receipt, then show success
                Task {
                    await findAndNavigateToLatestReceipt()
                }
            }
        } else {
            print("❌ Image upload failed: \(underlyingError)")
            await MainActor.run {
                isProcessing = false
                errorMessage = "Upload failed: \(underlyingError.localizedDescription)"
            }
        }
    } catch {
        print("❌ Image upload failed: \(error)")
        await MainActor.run {
            isProcessing = false
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }
}

    private func processPDF() async {
        guard let pdf = selectedPDF else { 
            print("📄 ❌ No PDF selected in processPDF")
            return 
        }
        
        print("📄 ✅ Starting PDF processing")
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            uploadSuccessMessage = nil
        }
        
        // Convert PDF to data
        guard let pdfData = pdf.dataRepresentation() else {
            await MainActor.run {
                errorMessage = "Failed to process PDF"
                isProcessing = false
            }
            return
        }
        
        // Upload PDF to server for processing
        let fileName = "receipt_\(Date().timeIntervalSince1970).pdf"
        
        do {
            print("📤 Starting PDF upload: \(fileName)")
            try await receiptStore.uploadReceiptToServer(pdfData: pdfData, fileName: fileName)
            
            await MainActor.run {
                isProcessing = false
                selectedPDF = nil
                uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                
                // Sync with server to get the new receipt, then show success
                Task {
                    await findAndNavigateToLatestReceipt()
                }
            }
        } catch APIService.APIError.uploadSuccessButNoData {
            // This is actually a success case - server accepted upload but returned no parseable data
            print("✅ PDF upload successful (server returned success but no data)")
            await MainActor.run {
                isProcessing = false
                selectedPDF = nil
                uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                
                // Sync with server to get the new receipt, then show success
                Task {
                    await findAndNavigateToLatestReceipt()
                }
            }
        } catch APIService.APIError.networkError(let underlyingError) {
            // Check if the underlying error is actually uploadSuccessButNoData
            if let apiError = underlyingError as? APIService.APIError,
               case .uploadSuccessButNoData = apiError {
                print("✅ PDF upload successful (wrapped success but no data)")
                await MainActor.run {
                    isProcessing = false
                    selectedPDF = nil
                    uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                    
                    // Sync with server to get the new receipt, then show success
                    Task {
                        await findAndNavigateToLatestReceipt()
                    }
                }
            } else {
                print("❌ PDF upload failed: \(underlyingError)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Upload failed: \(underlyingError.localizedDescription)"
                }
            }
        } catch {
            print("❌ PDF upload failed: \(error)")
            await MainActor.run {
                isProcessing = false
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func findAndNavigateToLatestReceipt() async {
        // Wait a moment for the server to process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Sync with server to get the latest receipts
        await MainActor.run {
            receiptStore.syncWithServer()
        }
        
        // Wait a moment for sync to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            // Show success alert and dismiss the view
            showingSuccessAlert = true
        }
    }
    
    @ViewBuilder
    private var selectedContentPreview: some View {
        VStack(spacing: 16) {
            // Preview header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Ready to Process")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                Button("Change") {
                    selectedImage = nil
                    selectedPDF = nil
                }
                .font(.subheadline)
                .foregroundColor(themeManager.accentColor)
            }
            
            // Preview content
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else if selectedPDF != nil {
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("PDF Selected")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Ready to upload and process")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(themeManager.cardBackgroundColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Upload button
            Button(action: {
                if selectedImage != nil {
                    Task {
                        await processImage()
                    }
                } else if selectedPDF != nil {
                    Task {
                        await processPDF()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                    
                    Text("Upload Receipt")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.accentColor)
                .cornerRadius(12)
            }
            .disabled(!accountService.canUploadReceipts)
        }
        .padding()
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
}

// MARK: - Modern Components

struct ModernUploadOptionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isRecommended: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(isDisabled ? .gray : color)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.gray.opacity(0.2) : color.opacity(0.1))
                )
            
            // Content
            VStack(spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isDisabled ? .gray : themeManager.primaryTextColor)
                    
                    if isRecommended && !isDisabled {
                        Text("Recommended")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(isDisabled ? .gray : themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDisabled ? Color.gray.opacity(0.1) : themeManager.cardBackgroundColor)
                .shadow(radius: isDisabled ? 0 : 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDisabled ? Color.gray.opacity(0.3) : color.opacity(0.3), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct TipRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(themeManager.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeManager.primaryTextColor)
            
            Spacer()
        }
    }
}

// MARK: - Camera and Photo Pickers

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false  // Don't force cropping
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker
        
        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
                print("📷 ✅ Photo selected from library")
            } else {
                print("📷 ❌ Failed to get photo from library")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraOverlayView = createCameraOverlay()
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    private func createCameraOverlay() -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.clear
        
        // Add a receipt frame guide
        let frameGuide = UIView()
        frameGuide.backgroundColor = UIColor.clear
        frameGuide.layer.borderColor = UIColor.white.cgColor
        frameGuide.layer.borderWidth = 2
        frameGuide.layer.cornerRadius = 8
        frameGuide.translatesAutoresizingMaskIntoConstraints = false
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Align receipt within frame"
        instructionLabel.textColor = UIColor.white
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        overlay.addSubview(frameGuide)
        overlay.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            frameGuide.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            frameGuide.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            frameGuide.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.8),
            frameGuide.heightAnchor.constraint(equalTo: overlay.heightAnchor, multiplier: 0.6),
            
            instructionLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: frameGuide.topAnchor, constant: -50),
            instructionLabel.widthAnchor.constraint(equalToConstant: 200),
            instructionLabel.heightAnchor.constraint(equalToConstant: 35)
        ])
        
        return overlay
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedPDF: PDFDocument?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf, UTType.image])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { 
                print("📄 No URL selected")
                return 
            }
            
            print("📄 Document picked: \(url.lastPathComponent)")
            
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Handle both PDF and image files
            if url.pathExtension.lowercased() == "pdf" {
                print("📄 Processing PDF file")
                if let pdf = PDFDocument(url: url) {
                    parent.selectedPDF = pdf
                    print("📄 ✅ PDF loaded successfully")
                } else {
                    print("📄 ❌ Failed to load PDF")
                }
            } else {
                print("📄 Processing image file: \(url.pathExtension)")
                
                // Handle image files by converting to PDF
                if let imageData = try? Data(contentsOf: url),
                   let image = UIImage(data: imageData) {
                    print("📄 ✅ Image loaded, converting to PDF")
                    
                    let pdfDocument = PDFDocument()
                    if let pdfPage = PDFPage(image: image) {
                        pdfDocument.insert(pdfPage, at: 0)
                        parent.selectedPDF = pdfDocument
                        print("📄 ✅ Image converted to PDF successfully")
                    } else {
                        print("📄 ❌ Failed to create PDF page from image")
                    }
                } else {
                    print("📄 ❌ Failed to load image data")
                }
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddReceiptView()
        .environmentObject(ReceiptStore())
        .environmentObject(ThemeManager())
} 