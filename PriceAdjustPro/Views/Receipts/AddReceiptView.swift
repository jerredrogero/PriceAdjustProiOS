import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

struct AddReceiptView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var receiptStore: ReceiptStore
    @StateObject private var pdfService = PDFService.shared
    
    @State private var showingImagePicker = false
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
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Add Receipt")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Choose how you'd like to add your receipt")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                
                // Upload Options
                VStack(spacing: 20) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        UploadOptionView(
                            icon: "camera",
                            title: "Take Photo",
                            description: "Capture receipt with camera"
                        )
                    }
                    
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        UploadOptionView(
                            icon: "doc",
                            title: "Upload PDF",
                            description: "Select PDF from files"
                        )
                    }
                }
                .padding()
                
                // Processing Status
                if isProcessing {
                    VStack(spacing: 15) {
                        ProgressView("Processing receipt...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        
                        if pdfService.processingProgress > 0 {
                            ProgressView(value: pdfService.processingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                                .frame(maxWidth: 200)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                // Success Message
                if let successMessage = uploadSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tips for best results:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("• Ensure the receipt is well-lit and flat")
                    Text("• Include the entire receipt in the frame")
                    Text("• Make sure text is clear and readable")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: EmptyView()
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedPDF: $selectedPDF)
        }
        .onChange(of: selectedImage) { _ in
            Task {
                await processImage()
            }
        }
        .onChange(of: selectedPDF) { _ in
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
            try await receiptStore.uploadReceiptToServer(pdfData: imageData, fileName: fileName)
            
            await MainActor.run {
                isProcessing = false
                selectedImage = nil
                uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                showingSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func processPDF() async {
        guard let pdf = selectedPDF else { return }
        
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
            try await receiptStore.uploadReceiptToServer(pdfData: pdfData, fileName: fileName)
            
            await MainActor.run {
                isProcessing = false
                selectedPDF = nil
                uploadSuccessMessage = "Receipt uploaded successfully! Processing will begin shortly."
                showingSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}

struct UploadOptionView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.red)
                .frame(width: 60)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
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
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
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
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
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
            guard let url = urls.first else { return }
            
            let pdf = PDFDocument(url: url)
            parent.selectedPDF = pdf
            
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
} 