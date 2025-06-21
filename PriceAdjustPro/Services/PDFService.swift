import Foundation
import PDFKit
import UIKit
import Vision
import VisionKit

class PDFService: ObservableObject {
    static let shared = PDFService()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    
    enum PDFError: Error, LocalizedError {
        case invalidPDF
        case noTextFound
        case processingFailed
        case ocrFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "Invalid PDF file"
            case .noTextFound:
                return "No text found in PDF"
            case .processingFailed:
                return "Failed to process PDF"
            case .ocrFailed:
                return "OCR processing failed"
            }
        }
    }
    
    private init() {}
    
    // MARK: - PDF Processing
    
    func processPDF(data: Data) async throws -> ReceiptData {
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 0.0
        }
        
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFError.invalidPDF
        }
        
        processingProgress = 0.2
        
        // Extract text from PDF
        let extractedText = extractTextFromPDF(pdfDocument)
        processingProgress = 0.5
        
        // If no text extracted, try OCR
        var finalText = extractedText
        if extractedText.isEmpty {
            finalText = try await performOCR(on: pdfDocument)
        }
        
        processingProgress = 0.8
        
        // Parse receipt data from text
        let receiptData = parseReceiptText(finalText)
        processingProgress = 1.0
        
        return receiptData
    }
    
    func convertImageToPDF(_ image: UIImage) -> Data? {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        let pdfData = pdfRenderer.pdfData { context in
            context.beginPage()
            image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        }
        
        return pdfData
    }
    
    // MARK: - Text Extraction
    
    private func extractTextFromPDF(_ document: PDFDocument) -> String {
        var text = ""
        
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                text += page.string ?? ""
                text += "\n"
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on document: PDFDocument) async throws -> String {
        guard let firstPage = document.page(at: 0) else {
            throw PDFError.invalidPDF
        }
        
        // Convert PDF page to image
        let pageRect = firstPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Perform OCR on image
        return try await performOCR(on: image)
    }
    
    private func performOCR(on image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: PDFError.ocrFailed)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: PDFError.ocrFailed)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Receipt Text Parsing
    
    private func parseReceiptText(_ text: String) -> ReceiptData {
        let lines = text.components(separatedBy: .newlines)
        
        // Parse basic info
        let storeName = extractStoreName(from: lines) ?? "Unknown Store"
        let date = extractDate(from: lines)
        let receiptNumber = extractReceiptNumber(from: lines) ?? "Unknown"
        let lineItems = extractLineItems(from: lines)
        
        // Calculate totals
        let totals = extractTotals(from: lines)
        
        let receiptData = ReceiptData(
            storeName: storeName,
            date: date,
            receiptNumber: receiptNumber,
            subtotal: totals.subtotal,
            tax: totals.tax,
            total: totals.total,
            lineItems: lineItems
        )
        
        return receiptData
    }
    
    private func extractStoreName(from lines: [String]) -> String? {
        for line in lines.prefix(5) { // Check first 5 lines
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedLine.localizedCaseInsensitiveContains("costco") {
                return "Costco Wholesale"
            }
        }
        return nil
    }
    
    private func extractDate(from lines: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        for line in lines {
            // Look for date patterns
            let dateRegex = try? NSRegularExpression(pattern: "\\d{1,2}/\\d{1,2}/\\d{4}", options: [])
            let range = NSRange(location: 0, length: line.count)
            
            if let match = dateRegex?.firstMatch(in: line, options: [], range: range) {
                let dateString = String(line[Range(match.range, in: line)!])
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractReceiptNumber(from lines: [String]) -> String? {
        for line in lines {
            // Look for receipt number patterns
            if line.localizedCaseInsensitiveContains("receipt") && line.contains("#") {
                let components = line.components(separatedBy: "#")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
    
    private func extractLineItems(from lines: [String]) -> [LineItemData] {
        var lineItems: [LineItemData] = []
        
        for line in lines {
            // Look for price patterns (ending with dollar amounts)
            let priceRegex = try? NSRegularExpression(pattern: "(.+?)\\s+(\\d+\\.\\d{2})\\s*$", options: [])
            let range = NSRange(location: 0, length: line.count)
            
            if let match = priceRegex?.firstMatch(in: line, options: [], range: range) {
                let nameRange = Range(match.range(at: 1), in: line)!
                let priceRange = Range(match.range(at: 2), in: line)!
                
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let priceString = String(line[priceRange])
                
                if let price = Double(priceString), !name.isEmpty {
                    let lineItem = LineItemData(
                        name: name,
                        price: price,
                        quantity: 1, // Default quantity
                        itemCode: nil,
                        category: nil
                    )
                    lineItems.append(lineItem)
                }
            }
        }
        
        return lineItems
    }
    
    private func extractTotals(from lines: [String]) -> (subtotal: Double, tax: Double, total: Double) {
        var subtotal: Double = 0.0
        var tax: Double = 0.0
        var total: Double = 0.0
        
        for line in lines.reversed() { // Start from bottom
            let lowercaseLine = line.lowercased()
            
            if lowercaseLine.contains("total") && !lowercaseLine.contains("subtotal") {
                total = extractAmountFromLine(line) ?? total
            } else if lowercaseLine.contains("subtotal") {
                subtotal = extractAmountFromLine(line) ?? subtotal
            } else if lowercaseLine.contains("tax") {
                tax = extractAmountFromLine(line) ?? tax
            }
        }
        
        return (subtotal, tax, total)
    }
    
    private func extractAmountFromLine(_ line: String) -> Double? {
        let amountRegex = try? NSRegularExpression(pattern: "\\d+\\.\\d{2}", options: [])
        let range = NSRange(location: 0, length: line.count)
        
        if let match = amountRegex?.firstMatch(in: line, options: [], range: range) {
            let amountString = String(line[Range(match.range, in: line)!])
            return Double(amountString)
        }
        
        return nil
    }
}

// Data models are defined in ReceiptModels.swift 