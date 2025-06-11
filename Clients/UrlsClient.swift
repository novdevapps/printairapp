import Dependencies
import Foundation
import UIKit

struct UrlsClient {
    private let openURL: (URL) -> Void
    private let privacyPolicy: () -> String
    private let termsOfService: () -> String
    private let shareApp: () -> String
    
    var shareAppUrl: URL { .init(string: shareApp())! }

    init(
        openURL: @escaping (URL) -> Void,
        privacyPolicy: @escaping () -> String,
        termsOfService: @escaping () -> String,
        shareApp: @escaping () -> String
    ) {
        self.openURL = openURL
        self.privacyPolicy = privacyPolicy
        self.termsOfService = termsOfService
        self.shareApp = shareApp
    }
    
    func openPrivacyPolicy() {
        guard let url = URL(string: privacyPolicy()) else { return }
        openURL(url)
    }
    
    func openTermsOfService() {
        guard let url = URL(string: privacyPolicy()) else { return }
        openURL(url)
    }
}

extension DependencyValues {
    var urlsClient: UrlsClient {
        get { self[UrlsClient.self] }
        set { self[UrlsClient.self] = newValue }
    }
}

extension UrlsClient: DependencyKey {
    static let liveValue = UrlsClient(
        openURL: { UIApplication.shared.open($0) },
        privacyPolicy: { "https://workdrive.zohopublic.eu/writer/open/jcwpp967a781dc61e42468ddf51e6d13b478e" },
        termsOfService: { "https://workdrive.zohopublic.eu/writer/open/jcwpp9f20304a62484211a5c5c76dc6675210" },
        shareApp: { "https://apps.apple.com/us/app/air-printer-smart-print/id6746974150" }
    )
    static let previewValue = UrlsClient(
        openURL: { UIApplication.shared.open($0) },
        privacyPolicy: { "https://workdrive.zohopublic.eu/writer/open/jcwpp967a781dc61e42468ddf51e6d13b478e" },
        termsOfService: { "https://workdrive.zohopublic.eu/writer/open/jcwpp9f20304a62484211a5c5c76dc6675210" },
        shareApp: { "https://apps.apple.com/us/app/air-printer-smart-print/id6746974150" }
    )
}
