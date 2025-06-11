
import Dependencies
import SwiftUI

struct MainScreen: View {
    enum Tab: Hashable, Identifiable {
        var id: Self { self }
        
        case printer
        case scanner
        case settings
        
        func image(isOn: Bool) -> String {
            let power = isOn ? "on" : "off"
            switch self {
            case .printer:
                return "tab_printer_\(power)"
            case .scanner:
                return "tab_scanner_\(power)"
            case .settings:
                return "tab_settings_\(power)"
            }
        }
    }
    enum ScannerState: Hashable, Identifiable {
        var id: Self { self }
        
        case none
        case takingPhoto
        case scanning
    }
    
    @State var tab: Tab = .printer
    @State var scannerState: ScannerState = .none
    @State var isPrintersPresented: Bool = false
    
    struct TabButton: View {
        let tab: Tab
        @Binding var selection: Tab
        
        var body: some View {
            Button {
                selection = tab
            } label: {
                Image(tab.image(isOn: selection == tab))
            }
        }
    }
    
    @State var scannerImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                TabView(selection: $tab) {
                    PrinterScreen()
                        .tag(Tab.printer)
                    
                    ScannerScreen()
                        .tag(Tab.scanner)
                    
                    SettingsScreen()
                        .tag(Tab.settings)
                }
                
                HStack {
                    TabButton(tab: .printer, selection: $tab)
                    
                    if case .scanner = tab {
                        Button {
                            scannerState = .takingPhoto
                            Task {
                                do {
                                    @Dependency(\.cameraService) var cameraService
                                    let image = try await cameraService.capturePhoto()
                                    scannerState = .scanning
                                    @Dependency(\.scannerClient) var scannerClient
                                    if let image = await scannerClient.scan(image: image) {
                                        self.scannerImage = image
                                    } else {
                                        self.scannerImage = image
                                    }
                                    scannerState = .none
                                } catch {
                                    scannerState = .none
                                }
                            }
                        } label: {
                            Image(Tab.scanner.image(isOn: true))
                        }
                        .overlay {
                            if scannerState != .none {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.black))
                            }
                        }
                        .push(item: $scannerImage) {
                            ImageViewerScreen(image: $0)
                        }
                    } else {
                        TabButton(tab: .scanner, selection: $tab)
                    }
                    
                    TabButton(tab: .settings, selection: $tab)
                }
                .disabled(scannerState != .none)
            }
            .secondaryBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SubscriptionContentButton {
                        isPrintersPresented = true
                    } content: {
                        Image("ic_items")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    SubscriptionsPresentationButton {
                        Image("ic_crown")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
            .navigationDestination(isPresented: $isPrintersPresented) {
                PrintersScreen()
                    .setAppBackButton()
            }
        }
    }
}

#Preview {
    MainScreen()
}

struct AppBackButton: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image("ic_back")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

extension View {
    func setAppBackButton() -> some View {
        navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppBackButton()
                }
            }
    }
}
