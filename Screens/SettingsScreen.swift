import Dependencies
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.requestReview) private var requestReview
    @Dependency(\.subscriptionClient) private var subscriptionClient
    @Dependency(\.urlsClient) private var urlsClient
    @State private var sharableItems: [SharableItem]?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                if !subscriptionClient.hasActiveSubscription {
                    SubscriptionButton {
                        Image("img_settings_promotion")
                            .resizable()
                            .scaledToFit()
                    }
                }

                Section(title: "General") {
                    if !subscriptionClient.hasActiveSubscription {
                        Button {
                            Task {
                                await subscriptionClient.restorePurchases()
                            }
                        } label: {
                            Item(imageName: "ic_restore", title: "Restore")
                        }
                        
                        SubscriptionButton {
                            Item(imageName: "ic_subscription", title: "Subscription")
                        }
                    }

                    Button {
                        urlsClient.openPrivacyPolicy()
                    } label: {
                        Item(imageName: "ic_privacy_policy", title: "Privacy policy")
                    }
                    
                    Button {
                        urlsClient.openTermsOfService()
                    } label: {
                        Item(imageName: "ic_terms_of_use", title: "Terms of use")
                    }

                    Button {
                        sharableItems = [.init(item: urlsClient.shareAppUrl)]
                    } label: {
                        Item(imageName: "ic_share", title: "Share APP")
                    }
                    
                    Button {
                        // TODO
                    } label: {
                        Item(imageName: "ic_support", title: "Support")
                    }
                }
            }
            .padding(16)
        }
        .secondaryBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Setting")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                SubscriptionButton {
                    Image("ic_crown")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .shareSheet(items: $sharableItems)
    }
    
    struct Item: View {
        let imageName: String
        let title: String
        
        var body: some View {
            HStack(spacing: 8) {
                Image(imageName)
                    .renderingMode(.template)
                    .foregroundStyle(Color.black)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color(hex: "#2C2C2C"))
                    .frame(height: 13)
                
            }
            .padding(.vertical, 8)
        }
    }
    
    struct Section<T: View>: View {
        let title: String?
        let content: T
        
        init(title: String? = nil, @ViewBuilder content: () -> T) {
            self.title = title
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if let title {
                    Text(title)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.black)
                }
                
                VStack {
                    content
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsScreen()
    }
}

struct SubscriptionButton<Content: View>: View {
    @StateObject private var subscriptionClient = Dependency(\.subscriptionClient).wrappedValue
    @State private var isSubscriptionPresented: Bool = false
    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        ZStack {
            if !subscriptionClient.hasActiveSubscription {
                Button {
                    withAnimation {
                        isSubscriptionPresented = true
                    }
                } label: {
                    content
                }
            }
        }
        .fullScreenCover(isPresented: $isSubscriptionPresented) {
            SubscriptionsScreen()
        }
    }
}

struct SubscriptionContentButton<Content: View>: View {
    @StateObject private var subscriptionClient = Dependency(\.subscriptionClient).wrappedValue
    @State private var isSubscriptionPresented: Bool = false
    private let content: Content
    let action: () -> Void
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button {
            withAnimation {
                if subscriptionClient.hasActiveSubscription {
                    action()
                } else {
                    isSubscriptionPresented = true
                }
            }
        } label: {
            content
        }
        .fullScreenCover(isPresented: $isSubscriptionPresented) {
            SubscriptionsScreen()
        }
    }
}
