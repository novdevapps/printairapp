
import SwiftUI

// MARK: - Image State Manager
final class ImageStateManager: ObservableObject {
    enum Operation {
        case rotate
        case crop(CGRect)
        case collage(rows: Int, columns: Int)
    }
    
    struct State: Equatable, Identifiable {
        let id = UUID()
        let image: UIImage
        let rotation: Double
        let cropRect: CGRect?
        let operation: Operation
        
        var printImage: UIImage {
            switch operation {
            case .collage:
                return image // Collage is already created with proper layout
            default:
                // Create a new image with the current rotation
                let rotatedSize = rotation.truncatingRemainder(dividingBy: 180) == 0 ? 
                    image.size : 
                    CGSize(width: image.size.height, height: image.size.width)
                
                let renderer = UIGraphicsImageRenderer(size: rotatedSize)
                return renderer.image { ctx in
                    // Move to center of the new size
                    ctx.cgContext.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
                    // Rotate
                    ctx.cgContext.rotate(by: rotation * .pi / 180)
                    // Move back, accounting for the new size
                    ctx.cgContext.translateBy(x: -image.size.width/2, y: -image.size.height/2)
                    
                    // Draw the image
                    image.draw(in: CGRect(origin: .zero, size: image.size))
                }
            }
        }
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.image == rhs.image &&
            lhs.rotation == rhs.rotation &&
            lhs.cropRect == rhs.cropRect
        }
    }
    
    @Published private(set) var currentState: State
    private let maxStackSize = 20
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    
    init(image: UIImage) {
        self.currentState = State(
            image: image,
            rotation: 0,
            cropRect: nil,
            operation: .rotate
        )
        saveState()
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func rotate() {
        let newRotation = (currentState.rotation + 90).truncatingRemainder(dividingBy: 360)
        updateState(
            image: currentState.image,
            rotation: newRotation,
            cropRect: currentState.cropRect,
            operation: .rotate
        )
    }
    
    func crop(_ rect: CGRect, in viewSize: CGSize) {
        let croppedImage = cropImage(currentState.image, to: rect, in: viewSize)
        updateState(
            image: croppedImage ?? currentState.image,
            rotation: currentState.rotation,
            cropRect: rect,
            operation: .crop(rect)
        )
    }
    
    func addToCollage() {
        let currentImage = currentState.image
        let (rows, columns) = if case .collage(let r, let c) = currentState.operation {
            (r, c)
        } else {
            (1, 1)
        }
        
        // Determine if we should add to right or bottom
        let shouldAddToRight = rows >= columns
        
        let newSize: CGSize
        let newRows: Int
        let newColumns: Int
        
        if shouldAddToRight {
            // Add to right
            newSize = CGSize(
                width: currentImage.size.width * 2,
                height: currentImage.size.height
            )
            newRows = rows
            newColumns = columns + 1
        } else {
            // Add to bottom
            newSize = CGSize(
                width: currentImage.size.width,
                height: currentImage.size.height * 2
            )
            newRows = rows + 1
            newColumns = columns
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { ctx in
            // Fill background with white
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: newSize))
            
            if shouldAddToRight {
                // Draw original image twice horizontally
                currentImage.draw(in: CGRect(x: 0, y: 0, width: currentImage.size.width, height: currentImage.size.height))
                currentImage.draw(in: CGRect(x: currentImage.size.width, y: 0, width: currentImage.size.width, height: currentImage.size.height))
            } else {
                // Draw original image twice vertically
                currentImage.draw(in: CGRect(x: 0, y: 0, width: currentImage.size.width, height: currentImage.size.height))
                currentImage.draw(in: CGRect(x: 0, y: currentImage.size.height, width: currentImage.size.width, height: currentImage.size.height))
            }
        }
        
        updateState(
            image: newImage,
            rotation: 0,
            cropRect: nil,
            operation: .collage(rows: newRows, columns: newColumns)
        )
    }
    
    func undo() {
        guard canUndo else { return }
        let previousState = undoStack.removeLast()
        redoStack.append(currentState)
        currentState = previousState
    }
    
    func redo() {
        guard canRedo else { return }
        let nextState = redoStack.removeLast()
        undoStack.append(currentState)
        currentState = nextState
    }
    
    private func updateState(image: UIImage, rotation: Double, cropRect: CGRect?, operation: Operation) {
        saveState()
        currentState = State(
            image: image,
            rotation: rotation,
            cropRect: cropRect,
            operation: operation
        )
        redoStack.removeAll()
    }
    
    private func saveState() {
        if undoStack.count >= maxStackSize {
            undoStack.removeFirst()
        }
        undoStack.append(currentState)
    }
    
    private func cropImage(_ image: UIImage, to rect: CGRect, in viewSize: CGSize) -> UIImage? {
        let imageSize = image.size
        let viewScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledImageSize = CGSize(
            width: imageSize.width * viewScale,
            height: imageSize.height * viewScale
        )
        
        let xOffset = (viewSize.width - scaledImageSize.width) / 2
        let yOffset = (viewSize.height - scaledImageSize.height) / 2
        
        let imageRect = CGRect(
            x: (rect.origin.x - xOffset) / viewScale,
            y: (rect.origin.y - yOffset) / viewScale,
            width: rect.width / viewScale,
            height: rect.height / viewScale
        )
        
        let imageScale = image.scale
        let scaledRect = CGRect(
            x: imageRect.origin.x * imageScale,
            y: imageRect.origin.y * imageScale,
            width: imageRect.width * imageScale,
            height: imageRect.height * imageScale
        )
        
        guard let cgImage = image.cgImage?.cropping(to: scaledRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: imageScale, orientation: image.imageOrientation)
    }
}

// MARK: - Image Viewer Screen
struct ImageViewerScreen: View {
    @StateObject private var stateManager: ImageStateManager
    @State private var isCropping = false
    @State private var cropRect: CGRect = .zero
    @State private var dragStart: CGPoint?
    @State private var sharableItems: [SharableItem]?
    
    init(image: UIImage) {
        _stateManager = StateObject(wrappedValue: ImageStateManager(image: image))
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                Image(uiImage: stateManager.currentState.printImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if isCropping {
                            CropOverlay(rect: $cropRect, geometry: geometry)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if isCropping {
                                    if dragStart == nil {
                                        dragStart = value.startLocation
                                    }
                                    
                                    if let start = dragStart {
                                        cropRect = CGRect(
                                            x: min(start.x, value.location.x),
                                            y: min(start.y, value.location.y),
                                            width: abs(value.location.x - start.x),
                                            height: abs(value.location.y - start.y)
                                        )
                                    }
                                }
                            }
                            .onEnded { _ in
                                if isCropping {
                                    stateManager.crop(cropRect, in: geometry.size)
                                    isCropping = false
                                    cropRect = .zero
                                    dragStart = nil
                                }
                            }
                    )
            }
            
            toolbarView
        }
        .primaryBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Circle()
                    .fill(Color(hex: "#404040"))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text("1/1")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white)
                    }
            }
        }
        .shareSheet(items: $sharableItems)
    }
    
    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack {
//                toolbarButton(imageName: "button_undo") {
//                    stateManager.undo()
//                }
//                .disabled(!stateManager.canUndo)
//                
//                toolbarButton(imageName: "button_redo") {
//                    stateManager.redo()
//                }
//                .disabled(!stateManager.canRedo)
                
                SubscriptionContentButton {
                    stateManager.addToCollage()
                } content: {
                    Image("button_collage")
                }
                
                toolbarButton(imageName: "button_share") {
                    sharableItems = [.init(item: stateManager.currentState.printImage)]
                }
                
                toolbarButton(imageName: "button_crop") {
                    isCropping.toggle()
                    if !isCropping {
                        cropRect = .zero
                        dragStart = nil
                    }
                }
                
                toolbarButton(imageName: "button_rotate") {
                    stateManager.rotate()
                }
            }
            .font(.title2)
            
            Button {
                PrintClient.printImage(stateManager.currentState.printImage)
            } label: {
                Text("Print")
                    .primaryButtonContent()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func toolbarButton(imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
        }
    }
}

struct CropOverlay: View {
    @Binding var rect: CGRect
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Crop rectangle
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }
}

#Preview {
    NavigationView {
        ImageViewerScreen(image: UIImage(named: "Img_onboarding_5")!)
    }
}
