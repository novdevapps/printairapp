import AVFoundation
import UIKit
import Combine
import SwiftUI
import Dependencies

enum CameraError: Error {
    case sessionNotRunning
    case noPhotoData
    case captureFailed(String)
}

final class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            if
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.session.canAddInput(videoInput)
            {
                self.session.addInput(videoInput)
                self.videoDeviceInput = videoInput
            } else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.setPreparedPhotoSettingsArray(
                    [AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])],
                    completionHandler: nil
                )
            } else {
                self.session.commitConfiguration()
                return
            }
            
            self.session.commitConfiguration()
            self.startSession()
        }
    }
    
    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func getSession() -> AVCaptureSession {
        session
    }
    
    func capturePhoto() async throws -> UIImage {
        guard isSessionRunning else {
            throw CameraError.sessionNotRunning
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            self.sessionQueue.async {
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            if let cont = photoContinuation {
                cont.resume(throwing: CameraError.captureFailed(error.localizedDescription))
                photoContinuation = nil
            }
            return
        }
        
        guard
            let data = photo.fileDataRepresentation(),
            let uiImage = UIImage(data: data)
        else {
            if let cont = photoContinuation {
                cont.resume(throwing: CameraError.noPhotoData)
                photoContinuation = nil
            }
            return
        }
        
        if let cont = photoContinuation {
            cont.resume(returning: uiImage)
            photoContinuation = nil
        }
        
        DispatchQueue.main.async {
            self.capturedImage = uiImage
        }
    }
}

extension CameraService: DependencyKey {
    static var liveValue: CameraService {
        CameraService()
    }

    static var previewValue: CameraService {
        let service = CameraService()
        service.stopSession()
        if let placeholder = UIImage(systemName: "photo")?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        {
            service.capturedImage = placeholder
        }
        return service
    }
}

extension DependencyValues {
    var cameraService: CameraService {
        get { self[CameraService.self] }
        set { self[CameraService.self] = newValue }
    }
}

struct CameraPreview: UIViewRepresentable {
    @StateObject private var cameraService = Dependency(\.cameraService).wrappedValue

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = cameraService.getSession()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = cameraService.getSession()
    }
    
    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
