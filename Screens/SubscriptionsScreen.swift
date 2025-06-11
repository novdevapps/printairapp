
import Dependencies
import SwiftUI

struct SubscriptionsPresentationButton<T: View>: View {
    @State var isSubscriptionPresente: Bool = false
    let content: T
    
    init(@ViewBuilder content: () -> T) {
        self.content = content()
    }
    
    var body: some View {
        Button {
            withAnimation {
                isSubscriptionPresente = true
            }
        } label: {
            content
        }
        .fullScreenCover(isPresented: $isSubscriptionPresente) {
            SubscriptionsScreen()
        }
    }
}

struct SubscriptionsScreen: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionClient = Dependency(\.subscriptionClient).wrappedValue
    @Dependency(\.urlsClient) var urlsClient
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    @State private var product: AnyIdentifiable?
    enum PromotionImage: Int, Hashable, Identifiable, CaseIterable {
        var id: Self { self }
        
        case image1 = 1
        case image2
        case image3
        
        var next: Self {
            switch self {
            case .image1:
                .image2
            case .image2:
                .image3
            case .image3:
                .image1
            }
        }
        var imageName: String {
            "img_inapp_\(rawValue)"
        }
        var description: String {
            switch self {
            case .image1:
                "PLAYLIST CREATION"
            case .image2:
                "MIX YOUR OWN BEATS"
            case .image3:
                "GET FULL ACCESS"
            }
        }
    }
    @State var image: PromotionImage = .image1
    
    init() {
        @Dependency(\.subscriptionClient) var subscriptionClient
        if case let .loaded(values) = subscriptionClient.products,
           let products = values[.insidePaywalls],
           let product = products.first {
            self._product = .init(initialValue: .init(product))
        } else {
            self._product = .init(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $image) {
                ForEach(PromotionImage.allCases) { tab in
                    Color.clear
                        .overlay(alignment: .bottom) {
                            Image(tab.imageName)
                                .resizable()
                                .scaledToFill()
                        }
                        .mask(RoundedRectangle(cornerRadius: 40))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .ignoresSafeArea()
                        .tag(tab)
                }
            }
            .ignoresSafeArea(edges: .top)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .safeAreaInset(edge: .bottom, spacing: -24) {
                VStack(spacing: 12) {
                    Text("GET PRO")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.white)
                    
                    SubscriptionProductsView(identifier: .insidePaywalls) { products in
                        let products = products.map({ AnyIdentifiable($0) })
                        HStack(spacing: 8) {
                            ForEach(products) { anyIdentifiable in
                                if let product = anyIdentifiable.value as? (any PurchasableProduct) {
                                    Item(
                                        title: product.displayName,
                                        type: product.durationDisplayName,
                                        price: product.displayPrice,
                                        unit: product.unitDisplayName,
                                        priceWeekly: product.weeklyPriceDisplayName,
                                        isSelected: .init(
                                            get: { self.product?.id == anyIdentifiable.id },
                                            set: { isSelected in
                                                if isSelected {
                                                    self.product = anyIdentifiable
                                                } else if self.product?.id == anyIdentifiable.id {
                                                    self.product = nil
                                                }
                                            }
                                        )
                                    )
                                }
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Text("3-day free trial")
                            Text("●").font(.system(size: 8))
                            Text("Recurring Bill")
                            Text("●").font(.system(size: 8))
                            Text("Cancel anytime")
                        }
                        .foregroundColor(Color.white)
                        .font(.system(size: 14))
                        
                        Button {
                            Task {
                                if let product = product?.value as? (any PurchasableProduct) {
                                    let result = await subscriptionClient.purchase(product)
                                    if result {
                                        await MainActor.run {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("Try Now")
                                .primaryButtonContent()
                        }
                        .disabled(product == nil || subscriptionClient.purchase == .inProgress)
                    }
                    
                    PrivacyRestoreTermsBar()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .primaryBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.black)
                    }
                    .padding(8)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    IndicatorView(color: .black, items: PromotionImage.allCases, selected: image)
                        .padding(8)
                }
            }
            .onReceive(timer) { _ in
                withAnimation {
                    image = image.next
                }
            }
        }
    }
    
    struct Item: View {
        let title: String
        let type: String
        let price: String
        let unit: String
        let priceWeekly: String
        @Binding var isSelected: Bool
        
        var mask: some Shape {
            RoundedRectangle(cornerRadius: 16)
        }
        var body: some View {
            Button {
                withAnimation {
                    isSelected.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Text(type)
                        .font(.system(size: 13, weight: .light))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(price)/\(unit)")
                        .font(.system(size: 12, weight: .light))
                }
                .padding(8)
                .foregroundStyle(isSelected ? Color(hex: "#2C2C2C") : Color(hex: "E1DFFF"))
                .mask(mask)
                .background {
                    mask
                        .stroke(Color(hex: "#FFFF20"), lineWidth: 1)
                }
                .background(
                    mask.fill(
                        LinearGradient(
                            colors: isSelected ? [Color(hex: "#FFFF20")] : [.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
            }
        }
    }
}

#Preview {
    SubscriptionsScreen()
}

struct AnyIdentifiable: Identifiable {
    let id: AnyHashable
    let value: Any
    
    init<T: Identifiable>(_ base: T) {
        self.id = base.id
        self.value = base
    }
}
