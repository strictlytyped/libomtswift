import Foundation

public enum OMTError: Error, Equatable {
    case invalidFrameVersion(UInt8)
    case invalidFrameType(UInt8)
    case invalidCodec(Int32)
    case invalidFrameLength
    case invalidAddress(String)
    case connectionClosed
    case unsupportedCodec(OMTCodec)
    case vmxFailure(Int32)
}

public struct OMTConstants {
    public static let discoveryServerDefaultPort = 6399
    public static let networkPortStart = 6400
    public static let networkPortEnd = 6600
    public static let networkReceiveBuffer = 8 * 1_048_576
    public static let videoMinSize = 65_536
    public static let videoMaxSize = 10_485_760
    public static let audioMinSize = 65_536
    public static let audioMaxSize = 1_048_576
    public static let metadataFrameSize = 65_536
    public static let urlPrefix = "omt://"
    public static let serviceType = "_omt._tcp."
}

public enum OMTPublicConstants {
    public static let discoveryServerDefaultPort = OMTConstants.discoveryServerDefaultPort
    public static let DISCOVERY_SERVER_DEFAULT_PORT = OMTConstants.discoveryServerDefaultPort
}

public struct OMTFrameType: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let none: OMTFrameType = []
    public static let metadata = OMTFrameType(rawValue: 1)
    public static let video = OMTFrameType(rawValue: 2)
    public static let audio = OMTFrameType(rawValue: 4)

    public static let None = none
    public static let Metadata = metadata
    public static let Video = video
    public static let Audio = audio
}

public struct OMTVideoFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none: OMTVideoFlags = []
    public static let interlaced = OMTVideoFlags(rawValue: 1)
    public static let alpha = OMTVideoFlags(rawValue: 2)
    public static let preMultiplied = OMTVideoFlags(rawValue: 4)
    public static let preview = OMTVideoFlags(rawValue: 8)
    public static let highBitDepth = OMTVideoFlags(rawValue: 16)

    public static let None = none
    public static let Interlaced = interlaced
    public static let Alpha = alpha
    public static let PreMultiplied = preMultiplied
    public static let Preview = preview
    public static let HighBitDepth = highBitDepth
}

public enum OMTCodec: Int32, Sendable {
    case vmx1 = 0x3158_4D56
    case fpa1 = 0x3141_5046
    case uyvy = 0x5956_5955
    case yuy2 = 0x3259_5559
    case bgra = 0x4152_4742
    case nv12 = 0x3231_564E
    case yv12 = 0x3231_5659
    case uyva = 0x4156_5955
    case p216 = 0x3631_3250
    case pa16 = 0x3631_4150

    public static let VMX1 = OMTCodec.vmx1
    public static let FPA1 = OMTCodec.fpa1
    public static let UYVY = OMTCodec.uyvy
    public static let YUY2 = OMTCodec.yuy2
    public static let BGRA = OMTCodec.bgra
    public static let NV12 = OMTCodec.nv12
    public static let YV12 = OMTCodec.yv12
    public static let UYVA = OMTCodec.uyva
    public static let P216 = OMTCodec.p216
    public static let PA16 = OMTCodec.pa16
}

public enum OMTPlatformType: Int, Sendable {
    case unknown = 0
    case win32 = 1
    case macOS = 2
    case linux = 3
    case iOS = 4

    public static let Unknown = OMTPlatformType.unknown
    public static let Win32 = OMTPlatformType.win32
    public static let MacOS = OMTPlatformType.macOS
    public static let Linux = OMTPlatformType.linux
}

public enum OMTColorSpace: Int32, Sendable {
    case undefined = 0
    case bt601 = 601
    case bt709 = 709

    public static let Undefined = OMTColorSpace.undefined
    public static let BT601 = OMTColorSpace.bt601
    public static let BT709 = OMTColorSpace.bt709
}

public enum OMTPreferredVideoFormat: Int, Sendable {
    case uyvy = 0
    case uyvyOrBGRA = 1
    case bgra = 2
    case uyvyOrUYVA = 3
    case uyvyOrUYVAOrP216OrPA16 = 4
    case p216 = 5

    public static let UYVY = OMTPreferredVideoFormat.uyvy
    public static let UYVYorBGRA = OMTPreferredVideoFormat.uyvyOrBGRA
    public static let BGRA = OMTPreferredVideoFormat.bgra
    public static let UYVYorUYVA = OMTPreferredVideoFormat.uyvyOrUYVA
    public static let UYVYorUYVAorP216orPA16 = OMTPreferredVideoFormat.uyvyOrUYVAOrP216OrPA16
    public static let P216 = OMTPreferredVideoFormat.p216
}

public struct OMTReceiveFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let none: OMTReceiveFlags = []
    public static let preview = OMTReceiveFlags(rawValue: 1)
    public static let includeCompressed = OMTReceiveFlags(rawValue: 2)
    public static let compressedOnly = OMTReceiveFlags(rawValue: 4)

    public static let None = none
    public static let Preview = preview
    public static let IncludeCompressed = includeCompressed
    public static let CompressedOnly = compressedOnly
}

public enum OMTQuality: Int, Sendable {
    case `default` = 0
    case low = 1
    case medium = 50
    case high = 100

    public var metadataValue: String {
        switch self {
        case .default:
            return "Default"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    public static let Default = OMTQuality.default
    public static let Low = OMTQuality.low
    public static let Medium = OMTQuality.medium
    public static let High = OMTQuality.high
}

public struct OMTStatistics: Equatable, Sendable {
    public var bytesSent: Int64
    public var bytesReceived: Int64
    public var bytesSentSinceLast: Int64
    public var bytesReceivedSinceLast: Int64
    public var frames: Int64
    public var framesSinceLast: Int64
    public var framesDropped: Int64
    public var codecTime: Int64
    public var codecTimeSinceLast: Int64

    public init(
        bytesSent: Int64 = 0,
        bytesReceived: Int64 = 0,
        bytesSentSinceLast: Int64 = 0,
        bytesReceivedSinceLast: Int64 = 0,
        frames: Int64 = 0,
        framesSinceLast: Int64 = 0,
        framesDropped: Int64 = 0,
        codecTime: Int64 = 0,
        codecTimeSinceLast: Int64 = 0
    ) {
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.bytesSentSinceLast = bytesSentSinceLast
        self.bytesReceivedSinceLast = bytesReceivedSinceLast
        self.frames = frames
        self.framesSinceLast = framesSinceLast
        self.framesDropped = framesDropped
        self.codecTime = codecTime
        self.codecTimeSinceLast = codecTimeSinceLast
    }

    public var BytesSent: Int64 {
        get { bytesSent }
        set { bytesSent = newValue }
    }

    public var BytesReceived: Int64 {
        get { bytesReceived }
        set { bytesReceived = newValue }
    }

    public var BytesSentSinceLast: Int64 {
        get { bytesSentSinceLast }
        set { bytesSentSinceLast = newValue }
    }

    public var BytesReceivedSinceLast: Int64 {
        get { bytesReceivedSinceLast }
        set { bytesReceivedSinceLast = newValue }
    }

    public var Frames: Int64 {
        get { frames }
        set { frames = newValue }
    }

    public var FramesSinceLast: Int64 {
        get { framesSinceLast }
        set { framesSinceLast = newValue }
    }

    public var FramesDropped: Int64 {
        get { framesDropped }
        set { framesDropped = newValue }
    }

    public var CodecTime: Int64 {
        get { codecTime }
        set { codecTime = newValue }
    }

    public var CodecTimeSinceLast: Int64 {
        get { codecTimeSinceLast }
        set { codecTimeSinceLast = newValue }
    }
}

public struct OMTVideoFormatDescription: Equatable, Sendable {
    public var codec: OMTCodec
    public var width: Int32
    public var height: Int32
    public var frameRateNumerator: Int32
    public var frameRateDenominator: Int32
    public var aspectRatio: Float
    public var flags: OMTVideoFlags
    public var colorSpace: OMTColorSpace

    public init(
        codec: OMTCodec,
        width: Int32,
        height: Int32,
        frameRateNumerator: Int32,
        frameRateDenominator: Int32,
        aspectRatio: Float,
        flags: OMTVideoFlags = [],
        colorSpace: OMTColorSpace = .undefined
    ) {
        self.codec = codec
        self.width = width
        self.height = height
        self.frameRateNumerator = frameRateNumerator
        self.frameRateDenominator = frameRateDenominator
        self.aspectRatio = aspectRatio
        self.flags = flags
        self.colorSpace = colorSpace
    }
}

public struct OMTAudioFormatDescription: Equatable, Sendable {
    public var codec: OMTCodec
    public var sampleRate: Int32
    public var samplesPerChannel: Int32
    public var channels: Int32
    public var activeChannels: UInt32
    public var reserved: Int32

    public init(
        codec: OMTCodec = .fpa1,
        sampleRate: Int32,
        samplesPerChannel: Int32,
        channels: Int32,
        activeChannels: UInt32,
        reserved: Int32 = 0
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.samplesPerChannel = samplesPerChannel
        self.channels = channels
        self.activeChannels = activeChannels
        self.reserved = reserved
    }
}

public struct OMTSize: Equatable, Sendable {
    public var width: Int32
    public var height: Int32

    public init(width: Int32 = 0, height: Int32 = 0) {
        self.width = width
        self.height = height
    }

    public var Width: Int32 {
        get { width }
        set { width = newValue }
    }

    public var Height: Int32 {
        get { height }
        set { height = newValue }
    }
}

public struct OMTMetadata: Equatable, Sendable {
    public var timestamp: Int64
    public var xml: String

    public init(timestamp: Int64 = 0, xml: String) {
        self.timestamp = timestamp
        self.xml = xml
    }

    public var Timestamp: Int64 {
        get { timestamp }
        set { timestamp = newValue }
    }

    public var XML: String {
        get { xml }
        set { xml = newValue }
    }
}

public struct OMTTally: Equatable, Sendable, CustomStringConvertible {
    public var preview: Bool
    public var program: Bool

    public init(preview: Bool = false, program: Bool = false) {
        self.preview = preview
        self.program = program
    }

    public init(preview: Int, program: Int) {
        self.preview = preview != 0
        self.program = program != 0
    }

    public var Preview: Int {
        get { preview ? 1 : 0 }
        set { preview = newValue != 0 }
    }

    public var Program: Int {
        get { program ? 1 : 0 }
        set { program = newValue != 0 }
    }

    public var metadataXML: String {
        #"<OMTTally Preview="\#(preview ? "true" : "false")" Program="\#(program ? "true" : "false")" />"#
    }

    public var description: String {
        "Preview: \(Preview) Program: \(Program)"
    }
}
