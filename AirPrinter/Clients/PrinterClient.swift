
import Combine
import Dependencies
import Foundation

struct Printer: Equatable, Identifiable {
    let id = UUID()
    let name: String
    let hostName: String
    let port: Int
    let type: String
}

struct PrinterClient {
    let start: @Sendable () -> AsyncStream<[Printer]>
}

final class LivePrinterClientCore: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let subject = CurrentValueSubject<[Printer], Never>([])
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []

    func stream() -> AsyncStream<[Printer]> {
        startDiscovery()
        return AsyncStream { continuation in
            let cancellable = subject
                .sink(receiveValue: { continuation.yield($0) })

            continuation.onTermination = { _ in
                cancellable.cancel()
                self.stopDiscovery()
            }
        }
    }

    private func startDiscovery() {
        stopDiscovery()
        browser = NetServiceBrowser()
        browser?.delegate = self
        for type in ["_ipp._tcp.", "_printer._tcp."] {
            browser?.searchForServices(ofType: type, inDomain: "local.")
        }
    }

    private func stopDiscovery() {
        browser?.stop()
        browser = nil
        services.removeAll()
        subject.send([])
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5)
        services.append(service)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let hostName = sender.hostName else { return }

        let printer = Printer(
            name: sender.name,
            hostName: hostName,
            port: sender.port,
            type: sender.type
        )

        var current = subject.value
        if !current.contains(where: { $0.hostName == printer.hostName && $0.port == printer.port }) {
            current.append(printer)
            subject.send(current)
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Failed to resolve \(sender.name): \(errorDict)")
    }
}

extension PrinterClient: DependencyKey {
    static let liveValue: PrinterClient = {
        let core = LivePrinterClientCore()
        return PrinterClient { core.stream() }
    }()

    static let previewValue: PrinterClient = {
        PrinterClient {
            AsyncStream { continuation in
                continuation.yield([
                    Printer(name: "Canon TS3300", hostName: "192.168.0.11", port: 631, type: "_ipp._tcp."),
                    Printer(name: "Brother HL-L2350", hostName: "192.168.0.42", port: 631, type: "_printer._tcp.")
                ])
            }
        }
    }()
}

extension DependencyValues {
    var printerClient: PrinterClient {
        get { self[PrinterClient.self] }
        set { self[PrinterClient.self] = newValue }
    }
}
