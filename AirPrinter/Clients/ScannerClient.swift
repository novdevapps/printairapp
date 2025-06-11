import CoreImage
import CoreImage.CIFilterBuiltins
import Dependencies
import UIKit
import Vision

struct ScannerClient {
    func scan(image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.8
        request.minimumAspectRatio = 0.5

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        var rectObservation: VNRectangleObservation?

        do {
            try handler.perform([request])
            rectObservation = request.results?.first
        } catch {
            return nil
        }

        guard let rect = rectObservation else {
            return image
        }

        let topLeft     = rect.topLeft.scaled(to: ciImage.extent.size)
        let topRight    = rect.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft  = rect.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = rect.bottomRight.scaled(to: ciImage.extent.size)

        let perspectiveFilter = CIFilter.perspectiveCorrection()
        perspectiveFilter.inputImage = ciImage
        perspectiveFilter.topLeft = topLeft
        perspectiveFilter.topRight = topRight
        perspectiveFilter.bottomLeft = bottomLeft
        perspectiveFilter.bottomRight = bottomRight

        guard let correctedCIImage = perspectiveFilter.outputImage else { return nil }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = correctedCIImage
        colorControls.contrast = 1.1
        colorControls.brightness = 0.0
        colorControls.saturation = 0.0

        guard let outputCIImage = colorControls.outputImage else { return nil }

        let context = CIContext()
        guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let texts = request.results?
            .compactMap { $0.topCandidates(1).first?.string } ?? []

        return texts.joined(separator: "\n")
    }
}

private extension CGPoint {
    /// Переводить нормалізовану точку Vision (0–1) у координати CIImage
    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(x: self.x * size.width, y: (1 - self.y) * size.height)
    }
}

extension ScannerClient: DependencyKey {
    static let liveValue: ScannerClient = ScannerClient()
}

extension DependencyValues {
    var scannerClient: ScannerClient {
        get { self[ScannerClient.self] }
        set { self[ScannerClient.self] = newValue }
    }
}
