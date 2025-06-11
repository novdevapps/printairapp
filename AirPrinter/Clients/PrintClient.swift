import SwiftUI
import UIKit
import PDFKit

/// SwiftUI-ready print client
struct PrintClient {
    
    /// Print a PDF at `pdfURL`
    static func printPDF(
        at pdfURL: URL,
        jobName: String? = nil,
        completion: UIPrintInteractionController.CompletionHandler? = nil
    ) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            print("🖨️ Printing is not available on this device.")
            return
        }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName ?? pdfURL.lastPathComponent
        info.outputType = .general
        controller.printInfo = info
        
        guard let data = try? Data(contentsOf: pdfURL) else {
            print("⚠️ Failed to load PDF data from \(pdfURL).")
            return
        }
        controller.printingItem = data
        controller.present(animated: true, completionHandler: completion)
    }
    
    /// Print a PDFDocument
    static func printPDF(
        document pdfDoc: PDFDocument,
        jobName: String = "PDF Document",
        completion: UIPrintInteractionController.CompletionHandler? = nil
    ) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            print("🖨️ Printing is not available on this device.")
            return
        }
        guard let data = pdfDoc.dataRepresentation() else {
            print("⚠️ Could not get data representation of PDFDocument.")
            return
        }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true, completionHandler: completion)
    }
    
    /// Print a `UIImage`
    static func printImage(
        _ image: UIImage,
        jobName: String = "Image Print",
        completion: UIPrintInteractionController.CompletionHandler? = nil
    ) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            print("🖨️ Printing is not available on this device.")
            return
        }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName
        info.outputType = .photo
        controller.printInfo = info
        
        controller.printingItem = image
        controller.present(animated: true, completionHandler: completion)
    }
}
