import Foundation

public struct OMTMediaFrame: Equatable, Sendable {
    public var type: OMTFrameType
    public var timestamp: Int64
    public var codec: OMTCodec
    public var width: Int32
    public var height: Int32
    public var stride: Int32
    public var flags: OMTVideoFlags
    public var frameRateNumerator: Int32
    public var frameRateDenominator: Int32
    public var aspectRatio: Float
    public var colorSpace: OMTColorSpace
    public var sampleRate: Int32
    public var channels: Int32
    public var samplesPerChannel: Int32
    public var data: Data
    public var compressedData: Data?
    public var frameMetadata: String?

    public init(
        type: OMTFrameType,
        timestamp: Int64 = 0,
        codec: OMTCodec,
        width: Int32 = 0,
        height: Int32 = 0,
        stride: Int32 = 0,
        flags: OMTVideoFlags = [],
        frameRateNumerator: Int32 = 0,
        frameRateDenominator: Int32 = 1,
        aspectRatio: Float = 0,
        colorSpace: OMTColorSpace = .undefined,
        sampleRate: Int32 = 0,
        channels: Int32 = 0,
        samplesPerChannel: Int32 = 0,
        data: Data = Data(),
        compressedData: Data? = nil,
        frameMetadata: String? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.codec = codec
        self.width = width
        self.height = height
        self.stride = stride
        self.flags = flags
        self.frameRateNumerator = frameRateNumerator
        self.frameRateDenominator = frameRateDenominator
        self.aspectRatio = aspectRatio
        self.colorSpace = colorSpace
        self.sampleRate = sampleRate
        self.channels = channels
        self.samplesPerChannel = samplesPerChannel
        self.data = data
        self.compressedData = compressedData
        self.frameMetadata = frameMetadata
    }
}

public struct OMTSenderInfo: Equatable, Sendable {
    public var productName: String
    public var manufacturer: String
    public var version: String

    public init(productName: String, manufacturer: String, version: String) {
        self.productName = productName
        self.manufacturer = manufacturer
        self.version = version
    }

    public var xml: String {
        #"<OMTInfo ProductName="\#(productName.omtEscapedXMLAttribute)" Manufacturer="\#(manufacturer.omtEscapedXMLAttribute)" Version="\#(version.omtEscapedXMLAttribute)" />"#
    }

    public init?(xml: String) {
        guard
            let productName = xml.omtXMLAttribute("ProductName"),
            let manufacturer = xml.omtXMLAttribute("Manufacturer"),
            let version = xml.omtXMLAttribute("Version")
        else {
            return nil
        }
        self.productName = productName
        self.manufacturer = manufacturer
        self.version = version
    }
}

extension String {
    var omtEscapedXMLAttribute: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func omtXMLAttribute(_ name: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = "\(escapedName)\\s*=+\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let valueRange = Range(match.range(at: 1), in: self) else { return nil }
        return String(self[valueRange])
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
