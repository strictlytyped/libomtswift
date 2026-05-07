import Darwin
import Foundation
import LibOMTVMXShim

public enum VMXProfile: Int32, Sendable {
    case `default` = 0
    case lowQuality = 33
    case standardQuality = 66
    case highQuality = 99
    case omtLowQuality = 133
    case omtStandardQuality = 166
    case omtHighQuality = 199
}

public enum VMXImageFormat: Sendable {
    case uyvy
    case yuy2
    case nv12
    case yv12
    case bgra
    case bgrx
    case uyva
    case p216
    case pa16
}

public final class OMTVMXCodec {
    public let width: Int32
    public let height: Int32
    public let profile: VMXProfile
    public let colorSpace: OMTColorSpace

    private let symbols: VMXSymbols
    private let instance: OpaquePointer

    public init(
        width: Int32,
        height: Int32,
        profile: VMXProfile = .default,
        colorSpace: OMTColorSpace = .undefined,
        symbolProvider: VMXSymbolProvider = .process
    ) throws {
        self.width = width
        self.height = height
        self.profile = profile
        self.colorSpace = colorSpace
        self.symbols = try VMXSymbols(provider: symbolProvider)
        guard let instance = symbols.create(width: width, height: height, profile: profile.rawValue, colorSpace: colorSpace.rawValue) else {
            throw OMTError.vmxFailure(-1)
        }
        self.instance = instance
    }

    deinit {
        symbols.destroy(instance)
    }

    public func setQuality(_ quality: Int32) {
        symbols.setQuality(instance, quality)
    }

    public func getQuality() -> Int32 {
        symbols.getQuality(instance)
    }

    public func encodedPreviewLength() -> Int32 {
        symbols.getEncodedPreviewLength(instance)
    }

    public func encode(
        _ format: VMXImageFormat,
        source: Data,
        stride: Int32,
        interlaced: Bool,
        maxOutputLength: Int
    ) throws -> Data {
        var output = Data(count: maxOutputLength)
        let resultLength = try source.withUnsafeBytes { sourceBytes in
            guard let base = sourceBytes.baseAddress else { throw OMTError.invalidFrameLength }
            let sourcePointer = UnsafeMutableRawPointer(mutating: base).assumingMemoryBound(to: UInt8.self)
            let result = callEncode(format, sourcePointer: sourcePointer, stride: stride, interlaced: interlaced)
            guard result == 0 else { throw OMTError.vmxFailure(result) }
            return symbols.saveTo(instance, &output, Int32(output.count))
        }
        guard resultLength > 0 else { throw OMTError.vmxFailure(resultLength) }
        output.count = Int(resultLength)
        return output
    }

    public func decode(
        _ format: VMXImageFormat,
        compressed: Data,
        stride: Int32,
        outputLength: Int,
        preview: Bool = false
    ) throws -> Data {
        var output = Data(count: outputLength)
        let loadResult = compressed.withUnsafeBytes { compressedBytes in
            symbols.loadFrom(instance, compressedBytes.bindMemory(to: UInt8.self).baseAddress, Int32(compressed.count))
        }
        guard loadResult == 0 else { throw OMTError.vmxFailure(loadResult) }

        let decodeResult = output.withUnsafeMutableBytes { outputBytes in
            let pointer = outputBytes.bindMemory(to: UInt8.self).baseAddress
            return callDecode(format, destination: pointer, stride: stride, preview: preview)
        }
        guard decodeResult == 0 else { throw OMTError.vmxFailure(decodeResult) }
        return output
    }

    private func callEncode(
        _ format: VMXImageFormat,
        sourcePointer: UnsafeMutablePointer<UInt8>,
        stride: Int32,
        interlaced: Bool
    ) -> Int32 {
        let interlacedValue: Int32 = interlaced ? 1 : 0
        switch format {
        case .uyvy:
            return symbols.encodeUYVY(instance, sourcePointer, stride, interlacedValue)
        case .yuy2:
            return symbols.encodeYUY2(instance, sourcePointer, stride, interlacedValue)
        case .bgra:
            return symbols.encodeBGRA(instance, sourcePointer, stride, interlacedValue)
        case .bgrx:
            return symbols.encodeBGRX(instance, sourcePointer, stride, interlacedValue)
        case .uyva:
            return symbols.encodeUYVA(instance, sourcePointer, stride, interlacedValue)
        case .p216:
            return symbols.encodeP216(instance, sourcePointer, stride, interlacedValue)
        case .pa16:
            return symbols.encodePA16(instance, sourcePointer, stride, interlacedValue)
        case .nv12, .yv12:
            return -2
        }
    }

    private func callDecode(
        _ format: VMXImageFormat,
        destination: UnsafeMutablePointer<UInt8>?,
        stride: Int32,
        preview: Bool
    ) -> Int32 {
        switch (format, preview) {
        case (.uyvy, false):
            return symbols.decodeUYVY(instance, destination, stride)
        case (.uyva, false):
            return symbols.decodeUYVA(instance, destination, stride)
        case (.yuy2, false):
            return symbols.decodeYUY2(instance, destination, stride)
        case (.bgra, false):
            return symbols.decodeBGRA(instance, destination, stride)
        case (.bgrx, false):
            return symbols.decodeBGRX(instance, destination, stride)
        case (.p216, false):
            return symbols.decodeP216(instance, destination, stride)
        case (.pa16, false):
            return symbols.decodePA16(instance, destination, stride)
        case (.uyvy, true):
            return symbols.decodePreviewUYVY(instance, destination, stride)
        case (.uyva, true):
            return symbols.decodePreviewUYVA(instance, destination, stride)
        case (.yuy2, true):
            return symbols.decodePreviewYUY2(instance, destination, stride)
        case (.bgra, true):
            return symbols.decodePreviewBGRA(instance, destination, stride)
        case (.bgrx, true):
            return symbols.decodePreviewBGRX(instance, destination, stride)
        default:
            return -2
        }
    }
}

public enum VMXSymbolProvider: Sendable {
    case process
    case path(String)
}

struct VMXSymbols {
    typealias Destroy = @convention(c) (OpaquePointer?) -> Void
    typealias SetQuality = @convention(c) (OpaquePointer?, Int32) -> Void
    typealias GetQuality = @convention(c) (OpaquePointer?) -> Int32
    typealias LoadFrom = @convention(c) (OpaquePointer?, UnsafePointer<UInt8>?, Int32) -> Int32
    typealias SaveTo = @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32
    typealias Transform = @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32
    typealias Encode = @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32, Int32) -> Int32
    typealias EncodedPreviewLength = @convention(c) (OpaquePointer?) -> Int32

    private let handle: UnsafeMutableRawPointer
    let destroy: Destroy
    let setQuality: SetQuality
    let getQuality: GetQuality
    let loadFrom: LoadFrom
    private let saveToRaw: SaveTo
    let encodeBGRA: Encode
    let encodeBGRX: Encode
    let encodeUYVY: Encode
    let encodeUYVA: Encode
    let encodeYUY2: Encode
    let encodeP216: Encode
    let encodePA16: Encode
    let decodeBGRA: Transform
    let decodeBGRX: Transform
    let decodeUYVY: Transform
    let decodeUYVA: Transform
    let decodeYUY2: Transform
    let decodeP216: Transform
    let decodePA16: Transform
    let decodePreviewBGRA: Transform
    let decodePreviewBGRX: Transform
    let decodePreviewUYVY: Transform
    let decodePreviewUYVA: Transform
    let decodePreviewYUY2: Transform
    let getEncodedPreviewLength: EncodedPreviewLength

    init(provider: VMXSymbolProvider) throws {
        let handle: UnsafeMutableRawPointer?
        switch provider {
        case .process:
            handle = OMTSwiftVMXOpen(nil, 0)
        case .path(let path):
            handle = path.withCString { OMTSwiftVMXOpen($0, 1) }
        }
        guard let handle else { throw OMTError.vmxFailure(-3) }
        self.handle = handle

        destroy = try Self.load(handle, "VMX_Destroy")
        setQuality = try Self.load(handle, "VMX_SetQuality")
        getQuality = try Self.load(handle, "VMX_GetQuality")
        loadFrom = try Self.load(handle, "VMX_LoadFrom")
        saveToRaw = try Self.load(handle, "VMX_SaveTo")
        encodeBGRA = try Self.load(handle, "VMX_EncodeBGRA")
        encodeBGRX = try Self.load(handle, "VMX_EncodeBGRX")
        encodeUYVY = try Self.load(handle, "VMX_EncodeUYVY")
        encodeUYVA = try Self.load(handle, "VMX_EncodeUYVA")
        encodeYUY2 = try Self.load(handle, "VMX_EncodeYUY2")
        encodeP216 = try Self.load(handle, "VMX_EncodeP216")
        encodePA16 = try Self.load(handle, "VMX_EncodePA16")
        decodeBGRA = try Self.load(handle, "VMX_DecodeBGRA")
        decodeBGRX = try Self.load(handle, "VMX_DecodeBGRX")
        decodeUYVY = try Self.load(handle, "VMX_DecodeUYVY")
        decodeUYVA = try Self.load(handle, "VMX_DecodeUYVA")
        decodeYUY2 = try Self.load(handle, "VMX_DecodeYUY2")
        decodeP216 = try Self.load(handle, "VMX_DecodeP216")
        decodePA16 = try Self.load(handle, "VMX_DecodePA16")
        decodePreviewBGRA = try Self.load(handle, "VMX_DecodePreviewBGRA")
        decodePreviewBGRX = try Self.load(handle, "VMX_DecodePreviewBGRX")
        decodePreviewUYVY = try Self.load(handle, "VMX_DecodePreviewUYVY")
        decodePreviewUYVA = try Self.load(handle, "VMX_DecodePreviewUYVA")
        decodePreviewYUY2 = try Self.load(handle, "VMX_DecodePreviewYUY2")
        getEncodedPreviewLength = try Self.load(handle, "VMX_GetEncodedPreviewLength")
    }

    func create(width: Int32, height: Int32, profile: Int32, colorSpace: Int32) -> OpaquePointer? {
        guard let pointer = OMTSwiftVMXCreate(handle, width, height, profile, colorSpace) else {
            return nil
        }
        return OpaquePointer(pointer)
    }

    func saveTo(_ instance: OpaquePointer, _ data: inout Data, _ maxLength: Int32) -> Int32 {
        data.withUnsafeMutableBytes { outputBytes in
            saveToRaw(instance, outputBytes.bindMemory(to: UInt8.self).baseAddress, maxLength)
        }
    }

    private static func load<T>(_ handle: UnsafeMutableRawPointer, _ name: String) throws -> T {
        guard let symbol = dlsym(handle, name) else {
            throw OMTError.vmxFailure(-4)
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
