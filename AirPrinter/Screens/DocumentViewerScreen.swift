import PDFKit
import SwiftUI
import UniformTypeIdentifiers

final class DocumentContainer: ObservableObject, Equatable, Identifiable {
    static func == (lhs: DocumentContainer, rhs: DocumentContainer) -> Bool {
        lhs.id == rhs.id
    }
    
    private(set) var id = UUID()
    let document: PDFDocument
    @Published private(set) var pageRotations: [Int: Int] = [:]
    
    // Undo/Redo stack with limited size to prevent memory issues
    private let maxStackSize = 20
    private var undoStack: [(document: PDFDocument, rotations: [Int: Int])] = []
    private var redoStack: [(document: PDFDocument, rotations: [Int: Int])] = []
    
    init(document: PDFDocument) {
        self.document = document
        saveState()
    }
    
    var pageCount: Int { document.pageCount }
    
    func page(at index: Int) -> PDFPage? {
        document.page(at: index)
    }
    
    func rotation(for page: Int) -> Int {
        pageRotations[page] ?? 0
    }
    
    func rotatePage(_ page: Int) {
        saveState()
        let currentRotation = rotation(for: page)
        pageRotations[page] = (currentRotation + 90) % 360
        id = .init()
        redoStack.removeAll()
    }
    
    /// Returns a new PDFDocument with all modifications (rotations, etc.) applied
    func getFinalDocument() -> PDFDocument {
        let finalDocument = PDFDocument()
        for i in 0..<pageCount {
            if let page = page(at: i)?.copy() as? PDFPage {
                // Apply the stored rotation
                page.rotation = rotation(for: i)
                finalDocument.insert(page, at: i)
            }
        }
        return finalDocument
    }
    
    private func saveState() {
        // Create a copy of current document and rotations
        let documentCopy = PDFDocument()
        for i in 0..<document.pageCount {
            if let page = document.page(at: i)?.copy() as? PDFPage {
                documentCopy.insert(page, at: i)
            }
        }
        
        // Limit stack size
        if undoStack.count >= maxStackSize {
            undoStack.removeFirst()
        }
        undoStack.append((document: documentCopy, rotations: pageRotations))
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func undo() {
        guard canUndo else { return }
        
        // Save current state to redo stack
        let currentState = (document: document, rotations: pageRotations)
        if redoStack.count >= maxStackSize {
            redoStack.removeFirst()
        }
        redoStack.append(currentState)
        
        // Restore previous state
        let previousState = undoStack.removeLast()
        restoreState(previousState)
    }
    
    func redo() {
        guard canRedo else { return }
        
        // Save current state to undo stack
        let currentState = (document: document, rotations: pageRotations)
        if undoStack.count >= maxStackSize {
            undoStack.removeFirst()
        }
        undoStack.append(currentState)
        
        // Restore next state
        let nextState = redoStack.removeLast()
        restoreState(nextState)
    }
    
    private func restoreState(_ state: (document: PDFDocument, rotations: [Int: Int])) {
        // Clear current document
        while document.pageCount > 0 {
            document.removePage(at: 0)
        }
        
        // Restore pages
        for i in 0..<state.document.pageCount {
            if let page = state.document.page(at: i)?.copy() as? PDFPage {
                document.insert(page, at: i)
            }
        }
        
        // Restore rotations
        pageRotations = state.rotations
        id = .init()
    }
    
    func createCollage() -> DocumentContainer {
        let newDocument = PDFDocument()
        let totalPages = pageCount
        
        // Process pages in groups of 4
        for startPage in stride(from: 0, to: totalPages, by: 4) {
            let endPage = min(startPage + 4, totalPages)
            let pageIndices = Array(startPage..<endPage)
            let pages = pageIndices.compactMap { page(at: $0) }
            
            // Create collage for this group of pages
            let collageImage = CollageGenerator.makeCollage(
                from: pages,
                columns: 2,
                rows: 2
            )
            
            // Add collage as a new page in the document
            if let page = PDFPage(image: collageImage) {
                newDocument.insert(page, at: newDocument.pageCount)
            }
        }
        
        return DocumentContainer(document: newDocument)
    }
    
    enum CollageGenerator {
        static func makeCollage(
            from pages: [PDFPage],
            columns: Int = 2,
            rows: Int = 2
        ) -> UIImage {
            // Get the first page to determine aspect ratio
            guard let firstPage = pages.first else { return UIImage() }
            let pageSize = firstPage.bounds(for: .cropBox).size
            
            // Calculate cell size to maintain aspect ratio
            let cellWidth = pageSize.width / 2  // Half of page width
            let cellHeight = pageSize.height / 2 // Half of page height
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            
            let totalSize = CGSize(
                width: cellSize.width * CGFloat(columns),
                height: cellSize.height * CGFloat(rows)
            )
            
            let renderer = UIGraphicsImageRenderer(size: totalSize)
            return renderer.image { ctx in
                // Fill background with white
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: totalSize))
                
                for (i, page) in pages.enumerated() {
                    let thumb = page.thumbnail(of: cellSize, for: .cropBox)
                    let col = i % columns
                    let row = i / columns
                    let origin = CGPoint(
                        x: CGFloat(col) * cellSize.width,
                        y: CGFloat(row) * cellSize.height
                    )
                    thumb.draw(in: CGRect(origin: origin, size: cellSize))
                }
            }
        }
    }
}

struct DocumentViewerScreen: View {
    @StateObject var originalDocument: DocumentContainer
    @State private var documents: [DocumentContainer] = []
    @State private var currentPage = 0
    
    private var document: DocumentContainer {
        documents.last ?? originalDocument
    }
    init(pdfDocument: PDFDocument) {
        self._originalDocument = StateObject(wrappedValue: .init(document: pdfDocument))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PDFKitView(
                document: document.document,
                currentPage: $currentPage,
                rotation: document.rotation(for: currentPage)
            )
            .id(document.id)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                toolbarView
            }
        }
        .primaryBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Circle()
                    .fill(Color(hex: "#404040"))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text("\(currentPage + 1)/\(document.pageCount)")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white)
                    }
            }
        }
    }
    
    private var toolbarView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                toolbarButton(imageName: "button_undo") {
                    document.undo()
                }
                .disabled(!document.canUndo)
                
                toolbarButton(imageName: "button_redo") {
                    document.redo()
                }
                .disabled(!document.canRedo)
                
                SubscriptionContentButton {
                    documents.append(originalDocument.createCollage())
                    currentPage = 0
                } content: {
                    Image("button_collage")
                }
                
                toolbarButton(imageName: "button_rotate") {
                    document.rotatePage(currentPage)
                }
            }
            
            Button {
                PrintClient.printPDF(document: document.getFinalDocument())
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

// MARK: — PDFKitView (with rotation)

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    let rotation: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        pdfView.delegate = context.coordinator
        pdfView.backgroundColor = .clear
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let page = document.page(at: currentPage) {
            page.rotation = rotation
            uiView.go(to: page)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        func pdfViewPageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else {
                return
            }
            parent.currentPage = pageIndex
        }
    }
}

// MARK: — Preview

extension PDFDocument {
    static var preview: PDFDocument = {
        let doc = PDFDocument()
        let colors: [UIColor] = [.red, .green, .blue, .yellow, .black, .brown, .purple]
        let pageSize = CGSize(width: 612, height: 792)
        for color in colors {
            let renderer = UIGraphicsImageRenderer(size: pageSize)
            let img = renderer.image { ctx in
                color.setFill()
                ctx.fill(CGRect(origin: .zero, size: pageSize))
            }
            if let page = PDFPage(image: img) {
                doc.insert(page, at: doc.pageCount)
            }
        }
        return doc
    }()
}

#Preview {
    NavigationView {
        DocumentViewerScreen(pdfDocument: .preview)
    }
}
