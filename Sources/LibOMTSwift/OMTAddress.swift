import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct OMTAddress: Equatable, Sendable, CustomStringConvertible {
    public var machineName: String
    public var name: String
    public var port: Int
    public var host: String?
    public var removed: Bool
    public var addresses: [String]

    public init(
        machineName: String = ProcessInfo.processInfo.hostName,
        name: String,
        port: Int,
        host: String? = nil,
        removed: Bool = false,
        addresses: [String] = []
    ) {
        self.machineName = Self.sanitizeMachineName(machineName)
        self.name = Self.sanitizeName(name)
        self.port = port
        self.host = host
        self.removed = removed
        self.addresses = addresses
        if let host, !host.isEmpty, !self.addresses.contains(host) {
            self.addresses.append(host)
        }
        limitFullNameLength()
    }

    public init(name: String, port: Int) {
        self.init(machineName: Self.defaultMachineName(), name: name, port: port)
    }

    public var fullName: String {
        Self.fullName(machineName: machineName, name: name)
    }

    public var url: String {
        "\(OMTConstants.urlPrefix)\(host ?? machineName):\(port)"
    }

    public var description: String {
        fullName
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

    public static func escapeFullName(_ fullName: String) -> String {
        fullName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ".", with: "\\.")
    }

    public static func sanitizeName(_ name: String) -> String {
        let sanitized = cleanedName(name)
        return sanitized.isEmpty ? "OMT" : sanitized
    }

    static func defaultMachineName() -> String {
#if canImport(UIKit)
        let deviceName = cleanedName(UIDevice.current.name)
        if !deviceName.isEmpty {
            return sanitizeMachineName(deviceName)
        }
#endif
        return sanitizeMachineName(ProcessInfo.processInfo.hostName)
    }

    static func sanitizeMachineName(_ machineName: String) -> String {
        var sanitized = cleanedName(machineName)
        if !sanitized.lowercased().hasSuffix(".local"),
           let separator = sanitized.firstIndex(of: ".") {
            sanitized = String(sanitized[..<separator])
        }
        return sanitized.isEmpty ? "Device" : sanitized
    }

    public static func unescapeFullName(_ fullName: String) -> String {
        var output = ""
        var iterator = fullName.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                output.append(character)
                continue
            }
            var digits = ""
            var scalars: [Character] = []
            for _ in 0..<3 {
                guard let next = iterator.next() else { break }
                if next.isNumber {
                    digits.append(next)
                } else {
                    scalars.append(next)
                    break
                }
            }
            if digits.count == 3, let value = UInt32(digits), let scalar = UnicodeScalar(value) {
                output.append(Character(scalar))
            } else {
                output += digits
                scalars.forEach { output.append($0) }
            }
        }
        return output
    }

    public static func isValid(_ fullName: String?) -> Bool {
        guard let fullName, !fullName.isEmpty else { return false }
        return fullName.contains("(") && fullName.contains(")")
    }

    public static func getMachineName(_ fullName: String) -> String {
        fullName.split(separator: "(", maxSplits: 1, omittingEmptySubsequences: false).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public static func getName(_ fullName: String) -> String {
        guard let open = fullName.firstIndex(of: "("), fullName.last == ")" else { return "" }
        return String(fullName[fullName.index(after: open)..<fullName.index(before: fullName.endIndex)])
    }

    public mutating func clearAddresses() {
        addresses.removeAll()
        host = nil
    }

    @discardableResult
    public mutating func addAddress(_ address: String) -> Bool {
        guard !address.isEmpty, !addresses.contains(address) else { return false }
        addresses.append(address)
        if host == nil {
            host = address
        }
        return true
    }

    public var xml: String {
        var xml = "<OMTAddress><Name>\(fullName.omtEscapedXMLText)</Name><Port>\(port)</Port>"
        if removed {
            xml += "<Removed>True</Removed>"
        }
        if !addresses.isEmpty {
            xml += "<Addresses>"
            for address in addresses {
                xml += "<IPAddress>\(address.omtEscapedXMLText)</IPAddress>"
            }
            xml += "</Addresses>"
        }
        xml += "</OMTAddress>"
        return xml
    }

    public init?(xml: String) {
        guard
            xml.hasPrefix("<OMTAddress") || xml.contains("<OMTAddress"),
            let fullName = xml.omtXMLElement("Name"),
            let portText = xml.omtXMLElement("Port"),
            let port = Int(portText),
            var address = Self.parseFullName(fullName, port: port)
        else {
            return nil
        }

        for ipAddress in xml.omtXMLElements("IPAddress") + xml.omtXMLElements("Address") {
            address.addAddress(ipAddress)
        }
        if xml.omtXMLElement("Removed")?.lowercased() == "true" {
            address.removed = true
        }
        self = address
    }

    mutating private func limitFullNameLength() {
        let maxFullNameLength = 63
        while fullName.utf8.count > maxFullNameLength {
            if name.utf8.count > 1 {
                name = Self.truncated(name, toUTF8ByteCount: name.utf8.count - 1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty {
                    name = "OMT"
                }
            } else if machineName.utf8.count > 1 {
                machineName = Self.truncated(machineName, toUTF8ByteCount: machineName.utf8.count - 1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if machineName.isEmpty {
                    machineName = "Device"
                }
            } else {
                break
            }
        }
    }

    private static func cleanedName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "\u{0}", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func truncated(_ value: String, toUTF8ByteCount maxBytes: Int) -> String {
        guard value.utf8.count > maxBytes else { return value }
        var output = ""
        var byteCount = 0
        for character in value {
            let characterByteCount = String(character).utf8.count
            guard byteCount + characterByteCount <= maxBytes else { break }
            output.append(character)
            byteCount += characterByteCount
        }
        return output
    }
}

extension String {
    var omtEscapedXMLText: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func omtXMLElement(_ name: String) -> String? {
        omtXMLElements(name).first
    }

    func omtXMLElements(_ name: String) -> [String] {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = "<\(escapedName)\\b[^>]*>(.*?)</\(escapedName)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: self) else {
                return nil
            }
            return String(self[valueRange])
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&amp;", with: "&")
        }
    }
}
