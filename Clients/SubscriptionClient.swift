import AdSupport
import AppTrackingTransparency
import ApphudSDK
import Combine
import Dependencies
import Foundation
import StoreKit

enum LoadState<T> {
    case initial
    case loading
    case loaded(T)
    case error(any Error)
}

enum PaywallIdentifier: String, Hashable, CaseIterable {
    case onboardPaywall = "onboardPaywall"
    case insidePaywalls = "paywallInside"
}

enum Purchase: Hashable {
    case none
    case inProgress
    case active
}

protocol PurchasableProduct: Hashable, Identifiable {
    var displayName: String { get }
    var displayPrice: String { get }
    var subscriptionPeriod: String { get }
    var durationDisplayName: String { get }
    var unitDisplayName: String { get }
    var weeklyPriceDisplayName: String { get }
    var durationTypeAndUnitDisplayName: String { get }
}

final class SubscriptionClient: ObservableObject {
    @Published private(set) var products: LoadState<[PaywallIdentifier: [any PurchasableProduct]]> = .initial
    @Published private(set) var purchase: Purchase = .none
    
    private let configAction: () async -> Void
    private let purchaseAction: (any PurchasableProduct) async -> Bool
    private let restorePurchasesAction: () async -> Void
    private let checkSubscriptionStatusAction: () async -> Void
    private let purchaseStream: AsyncStream<Purchase>
    private let productsStream: AsyncStream<LoadState<[PaywallIdentifier: [any PurchasableProduct]]>>
    private var purchaseStreamTask: Task<Void, Never>?
    private var productsStreamTask: Task<Void, Never>?
    
    init(
        configAction: @escaping () async -> Void,
        purchaseAction: @escaping (any PurchasableProduct) async -> Bool,
        restorePurchasesAction: @escaping () async -> Void,
        checkSubscriptionStatusAction: @escaping () async -> Void,
        purchaseStream: AsyncStream<Purchase>,
        productsStream: AsyncStream<LoadState<[PaywallIdentifier: [any PurchasableProduct]]>>
    ) {
        self.configAction = configAction
        self.purchaseAction = purchaseAction
        self.restorePurchasesAction = restorePurchasesAction
        self.checkSubscriptionStatusAction = checkSubscriptionStatusAction
        self.purchaseStream = purchaseStream
        self.productsStream = productsStream
        
        // Start listening to purchase stream
        purchaseStreamTask = Task { [weak self] in
            for await purchase in purchaseStream {
                await MainActor.run {
                    self?.purchase = purchase
                }
            }
        }
        
        // Start listening to products stream
        productsStreamTask = Task { [weak self] in
            for await products in productsStream {
                await MainActor.run {
                    self?.products = products
                }
            }
        }
    }
    
    deinit {
        purchaseStreamTask?.cancel()
        productsStreamTask?.cancel()
    }
    
    @MainActor
    func config() async {
        await configAction()
    }
    
    @MainActor
    func purchase(_ product: any PurchasableProduct) async -> Bool {
        await purchaseAction(product)
    }
    
    @MainActor
    func restorePurchases() async {
        await restorePurchasesAction()
    }
    
    @MainActor
    func checkSubscriptionStatus() async {
        await checkSubscriptionStatusAction()
    }
    
    func products(for identifier: PaywallIdentifier) -> [any PurchasableProduct]? {
        guard case let .loaded(products) = products else {
            return nil
        }
        return products[identifier]
    }
    
    var hasActiveSubscription: Bool { purchase == .active }
}

extension DependencyValues {
    var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClientKey.self] }
        set { self[SubscriptionClientKey.self] = newValue }
    }
}

struct SubscriptionClientKey: DependencyKey { }

// MARK: - Preview
extension SubscriptionClientKey {
    struct MockSubscriptionProduct: PurchasableProduct {
        let id: String = UUID().uuidString
        var displayName: String { "displayName" }
        var displayPrice: String { "displayPrice" }
        var subscriptionPeriod: String { "subscriptionPeriod" }
        var durationDisplayName: String { "durationDisplayName" }
        var unitDisplayName: String { "unitDisplayName" }
        var weeklyPriceDisplayName: String { "weeklyPriceDisplayName" }
        var durationTypeAndUnitDisplayName: String { "durationTypeAndUnitDisplayName" }
    }

    static let previewValue: SubscriptionClient = {
        let (purchaseStream, purchaseContinuation) = AsyncStream.makeStream(of: Purchase.self)
        return SubscriptionClient(
            configAction: { },
            purchaseAction: { _ in
                purchaseContinuation.yield(.active)
                return true
            },
            restorePurchasesAction: {
                purchaseContinuation.yield(.active)
            },
            checkSubscriptionStatusAction: { },
            purchaseStream: purchaseStream,
            productsStream: AsyncStream { continuation in
                continuation.yield(.loading)
                let mockProducts: LoadState<[PaywallIdentifier: [any PurchasableProduct]]> = .loaded([
                    .onboardPaywall: [MockSubscriptionProduct()],
                    .insidePaywalls: [MockSubscriptionProduct(), MockSubscriptionProduct(), MockSubscriptionProduct()]
                ])
                continuation.yield(mockProducts)
                continuation.finish()
            }
        )
    }()
}

// MARK: - Live
extension SubscriptionClientKey {
    static let liveValue: SubscriptionClient = {
        let client = LiveApphudDelegate()
        let (purchaseStream, purchaseContinuation) = AsyncStream.makeStream(of: Purchase.self)
        
        @MainActor
        func checkSubscriptionStatusAction() {
            purchaseContinuation.yield(.inProgress)
            let hasActiveSubscription = Apphud.hasActiveSubscription()
            if hasActiveSubscription {
                purchaseContinuation.yield(.active)
            } else {
                purchaseContinuation.yield(.none)
            }
        }
        
        return SubscriptionClient(
            configAction: {
                await Apphud.start(apiKey: "app_rh1oibqDzf5hS6BHw3r7tDiBcXZFJZ")
                await Apphud.setDeviceIdentifiers(
                    idfa: nil,
                    idfv: UIDevice.current.identifierForVendor?.uuidString
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    ATTrackingManager.requestTrackingAuthorization { status in
                        guard status == .authorized else { return }
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                        Apphud.setDeviceIdentifiers(
                            idfa: idfa,
                            idfv: UIDevice.current.identifierForVendor?.uuidString
                        )
                    }
                }
                Apphud.setDelegate(client)
                await checkSubscriptionStatusAction()
            },
            purchaseAction: { @MainActor product in
                guard let product = product as? LiveApphudDelegate.Product else { return false }
                return await withCheckedContinuation { continuation in
                    Apphud.purchase(product.apphudProduct) { result in
                        if result.success {
                            purchaseContinuation.yield(.active)
                        } else {
                            purchaseContinuation.yield(.none)
                        }
                        continuation.resume(returning: result.success)
                    }
                }
            },
            restorePurchasesAction: { @MainActor in
                purchaseContinuation.yield(.inProgress)
                return await withCheckedContinuation { continuation in
                    Apphud.restorePurchases { subscriptions, _, _ in
                        let hasActiveSubscription = subscriptions?.contains(where: { $0.isActive() }) ?? false
                        if hasActiveSubscription {
                            purchaseContinuation.yield(.active)
                        } else {
                            purchaseContinuation.yield(.none)
                        }
                        continuation.resume()
                    }
                }
            },
            checkSubscriptionStatusAction: { @MainActor in
                checkSubscriptionStatusAction()
            },
            purchaseStream: purchaseStream,
            productsStream: client.$products.asyncStream()
        )
    }()
}

final class LiveApphudDelegate: ApphudDelegate {
    struct Product: PurchasableProduct {
        var id: String { apphudProduct.productId }
        let apphudProduct: ApphudProduct
        let product: StoreKit.Product
        let subscription: StoreKit.Product.SubscriptionInfo
    }
    
    @Published var products: LoadState<[PaywallIdentifier: [any PurchasableProduct]]> = .initial
    
    func paywallsDidFullyLoad(paywalls: [ApphudPaywall]) {
        Task {
            let items = await paywalls.asyncReduce(into: [PaywallIdentifier: [Product]]()) { partialResult, apphudPaywall in
                if let paywallIdentifier = PaywallIdentifier(rawValue: apphudPaywall.identifier) {
                    partialResult[paywallIdentifier] = await apphudPaywall.products.asyncCompactMap { apphudProduct -> Product? in
                        if let product = try? await apphudProduct.product(), let subscription = product.subscription {
                            return Product(
                                apphudProduct: apphudProduct,
                                product: product,
                                subscription: subscription
                            )
                        } else {
                            return nil
                        }
                    }.sorted { lhsProduct, rhsProduct in
                        let lhsPeriod = lhsProduct.subscription.subscriptionPeriod
                        let rhsPeriod = rhsProduct.subscription.subscriptionPeriod
                        
                        // Define a custom order for the SubscriptionPeriod.Unit enum
                        let unitOrder: [StoreKit.Product.SubscriptionPeriod.Unit: Int] = [
                            .day: 0,
                            .week: 1,
                            .month: 2,
                            .year: 3
                        ]
                        
                        // Compare by unit first
                        if lhsPeriod.unit != rhsPeriod.unit {
                            return unitOrder[lhsPeriod.unit, default: 0] < unitOrder[rhsPeriod.unit, default: 0]
                        }
                        
                        // If units are the same, compare by number of units
                        return lhsPeriod.value < rhsPeriod.value
                    }
                }
            }
            products = .loaded(items)
        }
    }
}

extension LiveApphudDelegate.Product {
    var displayName: String {
        product.displayName
    }
    
    var displayPrice: String {
        product.displayPrice
    }
    
    var subscriptionPeriod: String {
        switch subscription.subscriptionPeriod.unit {
        case .day:
            return "Daily"
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        @unknown default:
            return "Unknown period"
        }
    }
    
    var durationDisplayName: String {
        switch subscription.subscriptionPeriod.unit {
        case .day, .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        default:
            return "Lifetime"
        }
    }
    
    var unitDisplayName: String {
        switch subscription.subscriptionPeriod.unit {
        case .day, .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        default:
            return "lifetime"
        }
    }
    
    var weeklyPriceDisplayName: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = product.priceFormatStyle.locale
        
        let price = product.price
        
        var divideBy: Decimal = 1
        let units = Decimal(subscription.subscriptionPeriod.value)
        
        switch subscription.subscriptionPeriod.unit {
        case .day:
            divideBy = 1
        case .month:
            divideBy = Decimal(4.28 * (units as NSDecimalNumber).doubleValue)
        case .year:
            divideBy = Decimal(4.28 * 12 * (units as NSDecimalNumber).doubleValue)
        default:
            divideBy = units
        }
        
        let weeklyPrice = price / divideBy
        
        return numberFormatter.string(from: weeklyPrice as NSDecimalNumber) ?? ""
    }
    
    var durationTypeAndUnitDisplayName: String {
        let period = subscription.subscriptionPeriod
        var unit = ""

        switch period.unit {
        case .day, .week:
            unit = "week"
        case .month:
            unit = "month"
        case .year:
            unit = "year"
        default:
            unit = "lifetime"
        }

        if period.unit == .month {
            let unitCount = period.value
            return "\(unitCount > 1 ? "\(unitCount) " : "")" + unit + (unitCount > 1 ? "s" : "")
        } else {
            return unit
        }
    }
}

extension Array {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            if let transformed = try await transform(element) {
                results.append(transformed)
            }
        }
        return results
    }
}

extension Array {
    func asyncReduce<Result>(
        into initialResult: Result,
        _ updateAccumulatingResult: (inout Result, Element) async throws -> Void
    ) async rethrows -> Result {
        var result = initialResult
        for element in self {
            try await updateAccumulatingResult(&result, element)
        }
        return result
    }
}

extension Publisher {
    func asyncStream() -> AsyncStream<Output> {
        AsyncStream { continuation in
            let cancellable = self.sink(
                receiveCompletion: { _ in
                    continuation.finish()
                },
                receiveValue: { value in
                    continuation.yield(value)
                }
            )

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }
}

