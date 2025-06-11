
import Dependencies
import SwiftUI

@main
struct AirPrinterApp: App {
    @AppStorage("isOnboarded") var isOnboarded: Bool = false
    
    init() {
        Task {
            @Dependency(\.subscriptionClient) var subscriptionClient
            await subscriptionClient.config()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isOnboarded {
                MainScreen()
            } else {
                OnboardingScreen {
                    withAnimation {
                        isOnboarded = true
                    }
                }
            }
        }
    }
}
