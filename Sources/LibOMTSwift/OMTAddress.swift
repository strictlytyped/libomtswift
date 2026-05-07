import Foundation

public struct OMTAddress: Equatable, Sendable {
    public var machineName: String
    public var name: String
    public var port: Int
    public var host: String?
    public var removed: Bool

    public init(
        machineName: String = ProcessInfo.processInfo.hostName,
        name: String,
        port: Int,
        host: String? = nil,
        removed: Bool = false
    ) {
        self.machineName = machineName
        self.name = name
        self.port = port
        self.host = host
        self.removed = removed
        limitFullNameLength()
    }

    public var fullName: String {
        Self.fullName(machineName: machineName, name: name)
    }

    public var url: String {
        "\(OMTConstants.urlPrefix)\(host ?? machineName):\(port)"
    }

    public static func fullName(machineName: String, name: String) -> String {
        "\(machineName) (\(name))"
    }

    public static func parseFullName(_ fullName: String, port: Int, host: String? = nil) -> OMTAddress? {
        guard let open = fullName.firstIndex(of: "("), fullName.last == ")" else { return nil }
        let machine = fullName[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
        let source = fullName[fullName.index(after: open)..<fullName.index(before: fullName.endIndex)]
        return OMTAddress(machineName: machine, name: String(source), port: port, host: host)
    }

    public static func parseURL(_ value: String) -> OMTAddress? {
        guard value.hasPrefix(OMTConstants.urlPrefix) else { return nil }
        let suffix = value.dropFirst(OMTConstants.urlPrefix.count)
        guard let separator = suffix.lastIndex(of: ":") else { return nil }
        let host = String(suffix[..<separator])
        guard let port = Int(suffix[suffix.index(after: separator)...]) else { return nil }
        return OMTAddress(machineName: host, name: host, port: port, host: host)
    }

    public var xml: String {
        var xml = "<OMTAddress><Name>\(fullName.omtEscapedXMLText)</Name><Port>\(port)</Port>"
        if removed {
            xml += "<Removed>True</Removed>"
        }
        if let host {
            xml += "<Addresses><Address>\(host.omtEscapedXMLText)</Address></Addresses>"
        }
        xml += "</OMTAddress>"
        return xml
    }

    mutating private func limitFullNameLength() {
        let maxFullNameLength = 63
        let oversize = fullName.count - maxFullNameLength
        guard oversize > 0, oversize < name.count else { return }
        name = String(name.dropLast(oversize)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var omtEscapedXMLText: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
