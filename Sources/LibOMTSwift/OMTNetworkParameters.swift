import Network

func omtTCPParameters() -> NWParameters {
    let tcp = NWProtocolTCP.Options()
    tcp.noDelay = true
    tcp.enableKeepalive = true
    return NWParameters(tls: nil, tcp: tcp)
}

extension NWEndpoint.Port {
    init(omtPort: Int) throws {
        guard let port = NWEndpoint.Port(rawValue: UInt16(omtPort)) else {
            throw OMTError.invalidAddress("Invalid OMT TCP port \(omtPort)")
        }
        self = port
    }
}
