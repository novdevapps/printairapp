
import SwiftUI
import PhotosUI
import PDFKit

struct PrinterScreen: View {
    @State var documentRequest: DocumentPicker.Request?
    @State var document: PDFDocument?
    @State var pickedItem: PhotosPickerItem? = nil
    @State var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Printer\nModule")
                .font(.system(size: 40, weight: .regular))
            
            Image("img_printer")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button {
                    documentRequest = .init(allowedContentTypes: [.pdf, .plainText, .rtf]) { files in
                        guard let url = files.first else {
                            return
                        }
                        document = PDFDocument(url: url)
                    }
                } label: {
                    Item(imageName: "ic_document", title: "Print\nDocuments")
                }
                
                PhotosPicker(
                    selection: $pickedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Item(imageName: "ic_image", title: "Print\nPhotos")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .secondaryBackground()
        .push(item: $document) {
            DocumentViewerScreen(pdfDocument: $0)
        }
        .push(item: $image) {
            ImageViewerScreen(image: $0)
        }
        .sheet(item: $documentRequest) {
            DocumentPicker(request: $0)
        }
        .onChange(of: pickedItem) { newItem in
            Task {
                // Asynchronously load Data from the PhotosPickerItem
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    image = uiImage
                }
            }
        }
    }
    
    struct Item: View {
        let imageName: String
        let title: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image(imageName)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                Image("button_arrow")
            }
            .padding(8)
            .padding(.leading, 8)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.white)
            )
        }
    }
}

#Preview {
    PrinterScreen()
}

extension View {
    /// Pushes a view when the optional item becomes non-nil.
    /// - Parameters:
    ///   - item: A binding to an optional identifiable item.
    ///   - destination: A view builder that returns the destination view.
    func push<Item, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        background(
            NavigationLink(destination: ZStack {
                if let item = item.wrappedValue {
                    destination(item)
                        .setAppBackButton()
                } else {
                    EmptyView()
                }
            }, isActive: Binding(
                get: { item.wrappedValue != nil },
                set: { isActive in if !isActive { item.wrappedValue = nil } }
            ), label: {
                EmptyView()
            })
            .hidden()
        )
    }
}
