
import Dependencies
import SwiftUI

struct ScannerScreen: View {
    @StateObject private var cameraService = Dependency(\.cameraService).wrappedValue
    
    var body: some View {
        CameraPreview()
            .onAppear {
                cameraService.startSession()
            }
            .onDisappear {
                cameraService.stopSession()
            }
            .ignoresSafeArea()
    }
}

#Preview {
    ScannerScreen()
}
