import Foundation

public final class OMTDiscovery: NSObject {
    public static let shared = OMTDiscovery()

    public var onUpdate: (([OMTAddress]) -> Void)?

    private let browser = NetServiceBrowser()
    private let queue = DispatchQueue(label: "com.strictly.omtswift.discovery")
    private var services: [String: NetService] = [:]
    private var resolvedAddresses: [String: OMTAddress] = [:]

    public override init() {
        super.init()
        browser.delegate = self
    }

    public var addresses: [OMTAddress] {
        queue.sync {
            resolvedAddresses.values.sorted { $0.fullName < $1.fullName }
        }
    }

    public static func getInstance() -> OMTDiscovery {
        shared
    }

    public static func GetInstance() -> OMTDiscovery {
        getInstance()
    }

    public func start() {
        browser.searchForServices(ofType: OMTConstants.serviceType, inDomain: "local.")
    }

    public func Start() {
        start()
    }

    public func stop() {
        browser.stop()
        queue.sync {
            services.removeAll()
            resolvedAddresses.removeAll()
        }
        publish()
    }

    public func Stop() {
        stop()
    }

    public func find(_ fullNameOrURL: String) -> OMTAddress? {
        if let urlAddress = OMTAddress.parseURL(fullNameOrURL) {
            return urlAddress
        }
        return queue.sync {
            resolvedAddresses[fullNameOrURL]
        }
    }

    public func getAddresses() -> [String] {
        addresses.map(\.fullName)
    }

    public func GetAddresses() -> [String] {
        getAddresses()
    }

    private func publish() {
        let values = addresses
        DispatchQueue.main.async { [onUpdate] in
            onUpdate?(values)
        }
    }
}

extension OMTDiscovery: NetServiceBrowserDelegate, NetServiceDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        queue.sync {
            services[service.name] = service
        }
        service.resolve(withTimeout: 5)
        if !moreComing {
            publish()
        }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        queue.sync {
            services.removeValue(forKey: service.name)
            if var address = resolvedAddresses.removeValue(forKey: service.name) {
                address.removed = true
                resolvedAddresses[service.name] = address
            }
        }
        if !moreComing {
            publish()
        }
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        guard sender.port > 0 else { return }
        let host = sender.hostName ?? sender.name
        guard var address = OMTAddress.parseFullName(sender.name, port: sender.port, host: host) else {
            return
        }
        address.removed = false
        queue.sync {
            resolvedAddresses[sender.name] = address
        }
        publish()
    }
}
