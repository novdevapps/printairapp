import Dependencies
import SwiftUI

struct OnboardingScreen: View {
    @Environment(\.requestReview) private var requestReview
    @StateObject private var subscriptionClient = Dependency(\.subscriptionClient).wrappedValue
    @Dependency(\.urlsClient) private var urlsClient
    
    enum Tab: Int, Identifiable, Hashable, CaseIterable {
        var id: Self { self }
        
        case page1 = 1
        case page2
        case page3
        case page4
        case paywall
    }
    @State var tab: Tab = .page1
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    struct Page: View {
        let tab: Tab
        
        var title: String? {
            switch tab {
            case .page1:
                "Welcome"
            case .page2:
                "Built-in"
            case .page3:
                "Review"
            case .page4:
                "Print"
            case .paywall:
                nil
            }
        }
        
        var subtitle: String {
            switch tab {
            case .page1:
                "To Your Air printer"
            case .page2:
                "Easy Scanner"
            case .page3:
                "Our App for Improve"
            case .page4:
                "Photos & Documents"
            case .paywall:
                "GET PRO"
            }
        }
        
        
        var description: String? {
            switch tab {
            case .page1:
                nil
            case .page2:
                nil
            case .page3:
                nil
            case .page4:
                nil
            case .paywall:
                "Start using the full app functionality with a risk-free 3-days free trial, then for %@%@ per week or proceed with a limited version"
            }
        }
        
        var imageName: String {
            "Img_onboarding_\(tab.rawValue)"
        }
        
        var body: some View {
            VStack(spacing: -24) {
                Color.clear
                    .overlay(alignment: .bottom) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .mask(RoundedRectangle(cornerRadius: 40))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .ignoresSafeArea()
                
                
//                Color.clear
//                    .overlay(alignment: .top) {
//                        Image(imageName)
//                            .resizable()
//                            .scaledToFit()
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.top, 16)
//                    .ignoresSafeArea()
                    
                
                VStack(spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color(hex: "E1DFDE"))
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(hex: "FFFF20"))
                    
                    if let description {
                        SubscriptionProductsView(identifier: .onboardPaywall) { products in
                            if let product = products.first {
                                Text(String(format: description, product.displayPrice, product.durationTypeAndUnitDisplayName))
                                    .font(.system(size: 12, weight: .light))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color(hex: "FFFFFF"))
                            }
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Page(tab: tab)
                        .tag(tab)
                }
            }
            .ignoresSafeArea(edges: .top)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    if let next = tab.next {
                        Button {
                            withAnimation {
                                if next == .page4 {
                                    requestReview()
                                }
                                tab = next
                            }
                        } label: {
                            Text("Continue")
                                .primaryButtonContent()
                        }
                    } else if case let .loaded(values) = subscriptionClient.products,
                              let product = values[.onboardPaywall]?.first {
                        if subscriptionClient.purchase == .inProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Button {
                                Task {
                                    await subscriptionClient.purchase(product)
                                }
                            } label: {
                                Text("Continue")
                                    .primaryButtonContent()
                            }
                        }
                    }
                    
                    PrivacyRestoreTermsBar()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .primaryBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if tab == .paywall {
                        Button {
                            withAnimation {
                                completion()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color.white)
                        }
                        .padding(8)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    let color: Color = tab == .paywall ? .white : .black
                    IndicatorView(color: color, items: Tab.allCases, selected: tab)
                        .padding(8)
                }
            }
            .animation(.default, value: tab)
        }
    }
}

extension OnboardingScreen.Tab {
    var next: Self? {
        switch self {
        case .page1:
            return .page2
        case .page2:
            return .page3
        case .page3:
            return .page4
        case .page4:
            @Dependency(\.subscriptionClient) var subscriptionClient
            if subscriptionClient.hasActiveSubscription {
                return nil
            } else {
                return .paywall
            }
        case .paywall:
            return nil
        }
    }
}

#Preview {
    OnboardingScreen { }
}

struct IndicatorView<T: Hashable & Identifiable>: View {
    var color: Color
    let items: [T]
    var selected: T?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = item == selected
                color.opacity(isSelected ? 1 : 0.4)
                    .aspectRatio(isSelected ? (10 / 3) : 1, contentMode: .fit)
                    .mask(Capsule())
            }
        }
        .frame(height: 12)
    }
}

struct PrivacyRestoreTermsBar: View {
    @Dependency(\.urlsClient) private var urlsClient
    @Dependency(\.subscriptionClient) private var subscriptionClient
    
    var body: some View {
        HStack {
            Button {
                urlsClient.openPrivacyPolicy()
            } label: {
                Text("Privacy Policy")
                    .frame(maxWidth: .infinity)
            }
            
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 1)
            
            Button {
                Task {
                    await subscriptionClient.restorePurchases()
                }
            } label: {
                Text("Restore")
                    .frame(maxWidth: .infinity)
            }
            
            Capsule()
                .frame(width: 1)
            
            Button {
                urlsClient.openTermsOfService()
            } label: {
                Text("Terms of use")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 16, weight: .light))
        .foregroundStyle(Color(hex: "#AEABAB"))
        .frame(height: 16)
    }
}

struct SubscriptionProductsView<T: View>: View {
    @Dependency(\.subscriptionClient) private var subscriptionClient
    let identifier: PaywallIdentifier
    let productsView: ([any PurchasableProduct]) -> T
    
    init(identifier: PaywallIdentifier, @ViewBuilder productsView: @escaping ([any PurchasableProduct]) -> T) {
        self.identifier = identifier
        self.productsView = productsView
    }
    
    var body: some View {
        if let products = subscriptionClient.products(for: identifier) {
            productsView(products)
        } else {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding(32)
        }
    }
}
