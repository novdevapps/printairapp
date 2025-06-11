import SwiftUI
import UIKit

struct SharableItem: Hashable {
    let id = UUID()
    let item: Any
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SharableItem, rhs: SharableItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

struct ShareModifier: ViewModifier {
    @Binding var items: [SharableItem]?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: .init(get: { items != nil }, set: { items = $0 ? items : nil })) {
                ShareSheet(items: items?.map(\.item) ?? [])
            }
    }
}

extension View {
    func shareSheet(items: Binding<[SharableItem]?>) -> some View {
        modifier(ShareModifier(items: items))
    }
}

struct ShareItemsButton<Content: View>: View {
    @State private var sharableItems: [SharableItem]?
    private let items: [SharableItem]
    private let content: Content
    
    init(item: SharableItem, @ViewBuilder content: () -> Content) {
        self.items = [item]
        self.content = content()
    }
    
    init(items: [SharableItem], @ViewBuilder content: () -> Content) {
        self.items = items
        self.content = content()
    }
    
    var body: some View {
        Button {
            sharableItems = items
        } label: {
            content
        }
        .shareSheet(items: $sharableItems)
    }
}
