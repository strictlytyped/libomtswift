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

    public var frameRate: Float {
        get { OMTUtils.toFrameRate(frameRateNumerator, frameRateDenominator) }
        set {
            let values = OMTUtils.fromFrameRate(newValue)
            frameRateNumerator = values.numerator
            frameRateDenominator = values.denominator
        }
    }

    public var `Type`: OMTFrameType {
        get { type }
        set { type = newValue }
    }

    public var Timestamp: Int64 {
        get { timestamp }
        set { timestamp = newValue }
    }

    public var Codec: Int32 {
        get { codec.rawValue }
        set { codec = OMTCodec(rawValue: newValue) ?? codec }
    }

    public var Width: Int32 {
        get { width }
        set { width = newValue }
    }

    public var Height: Int32 {
        get { height }
        set { height = newValue }
    }

    public var Stride: Int32 {
        get { stride }
        set { stride = newValue }
    }

    public var Flags: OMTVideoFlags {
        get { flags }
        set { flags = newValue }
    }

    public var FrameRateN: Int32 {
        get { frameRateNumerator }
        set { frameRateNumerator = newValue }
    }

    public var FrameRateD: Int32 {
        get { frameRateDenominator }
        set { frameRateDenominator = newValue }
    }

    public var FrameRate: Float {
        get { frameRate }
        set { frameRate = newValue }
    }

    public var AspectRatio: Float {
        get { aspectRatio }
        set { aspectRatio = newValue }
    }

    public var ColorSpace: OMTColorSpace {
        get { colorSpace }
        set { colorSpace = newValue }
    }

    public var SampleRate: Int32 {
        get { sampleRate }
        set { sampleRate = newValue }
    }

    public var Channels: Int32 {
        get { channels }
        set { channels = newValue }
    }

    public var SamplesPerChannel: Int32 {
        get { samplesPerChannel }
        set { samplesPerChannel = newValue }
    }

    public var DataLength: Int {
        data.count
    }

    public var CompressedLength: Int {
        compressedData?.count ?? 0
    }

    public var FrameMetadataLength: Int {
        guard let frameMetadata else { return 0 }
        return Data(frameMetadata.utf8).count + 1
    }
}

public struct OMTSenderInfo: Equatable, Sendable {
    public var productName: String
    public var manufacturer: String
    public var version: String

    public init(productName: String = "", manufacturer: String = "", version: String = "") {
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

    public var ProductName: String {
        get { productName }
        set { productName = newValue }
    }

    public var Manufacturer: String {
        get { manufacturer }
        set { manufacturer = newValue }
    }

    public var Version: String {
        get { version }
        set { version = newValue }
    }

    public func toXML() -> String {
        xml
    }

    public func ToXML() -> String {
        xml
    }

    public static func fromXML(_ xml: String) -> OMTSenderInfo? {
        OMTSenderInfo(xml: xml)
    }

    public static func FromXML(_ xml: String) -> OMTSenderInfo? {
        fromXML(xml)
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
