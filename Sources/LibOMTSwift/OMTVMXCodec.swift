import Darwin
import Foundation
import LibOMTVMXShim

public enum VMXProfile: Int32, Sendable {
    case none = 0
    case `default` = 1
    case lowQuality = 33
    case standardQuality = 66
    case highQuality = 99
    case omtLowQuality = 133
    case omtStandardQuality = 166
    case omtHighQuality = 199
}

public enum VMXImageFormat: Sendable {
    case none
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
    public let framesPerSecond: Int32
    public let profile: VMXProfile
    public let colorSpace: OMTColorSpace

    private let symbols: VMXSymbols
    private let instance: OpaquePointer

    public init(
        width: Int32,
        height: Int32,
        framesPerSecond: Int32 = 0,
        profile: VMXProfile = .default,
        colorSpace: OMTColorSpace = .undefined,
        symbolProvider: VMXSymbolProvider = .process
    ) throws {
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.profile = profile
        self.colorSpace = colorSpace
        self.symbols = try VMXSymbols(provider: symbolProvider)
        let createProfile = profile == .default ? VMXProfile.omtStandardQuality : profile
        guard let instance = symbols.create(width: width, height: height, profile: createProfile.rawValue, colorSpace: colorSpace.rawValue) else {
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
        guard format != .none else { return Data() }
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
        guard format != .none else { return Data() }
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

    public func getPreviewSize(interlaced: Bool) -> OMTSize {
        var previewWidth = width >> 3
        var previewHeight = height >> 3
        if previewWidth % 2 != 0 {
            previewWidth += 1
        }
        if interlaced, previewHeight % 2 != 0 {
            previewHeight -= 1
        }
        return OMTSize(width: previewWidth, height: previewHeight)
    }

    public func calculatePSNR(_ image1: Data, _ image2: Data, stride: Int32, bytesPerPixel: Int32, size: OMTSize) -> Float {
        guard image1.count == image2.count, !image1.isEmpty else { return 0 }
        var sumSquaredError: Double = 0
        for index in image1.indices {
            let diff = Double(Int(image1[index]) - Int(image2[index]))
            sumSquaredError += diff * diff
        }
        guard sumSquaredError > 0 else { return Float.infinity }
        let mse = sumSquaredError / Double(max(1, Int(size.width * size.height * bytesPerPixel)))
        return Float(10.0 * log10((255.0 * 255.0) / mse))
    }

    private func callEncode(
        _ format: VMXImageFormat,
        sourcePointer: UnsafeMutablePointer<UInt8>,
        stride: Int32,
        interlaced: Bool
    ) -> Int32 {
        let interlacedValue: Int32 = interlaced ? 1 : 0
        switch format {
        case .none:
            return -2
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
        case (.none, _):
            return -2
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
    typealias Destroy = (OpaquePointer?) -> Void
    typealias SetQuality = (OpaquePointer?, Int32) -> Void
    typealias GetQuality = (OpaquePointer?) -> Int32
    typealias LoadFrom = (OpaquePointer?, UnsafePointer<UInt8>?, Int32) -> Int32
    typealias SaveTo = (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32
    typealias Transform = (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32
    typealias Encode = (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32, Int32) -> Int32
    typealias EncodedPreviewLength = (OpaquePointer?) -> Int32

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
        _ = provider
        destroy = { OMTSwiftVMXDestroy(Self.rawPointer($0)) }
        setQuality = { OMTSwiftVMXSetQuality(Self.rawPointer($0), $1) }
        getQuality = { OMTSwiftVMXGetQuality(Self.rawPointer($0)) }
        loadFrom = { OMTSwiftVMXLoadFrom(Self.rawPointer($0), $1, $2) }
        saveToRaw = { OMTSwiftVMXSaveTo(Self.rawPointer($0), $1, $2) }
        encodeBGRA = { OMTSwiftVMXEncodeBGRA(Self.rawPointer($0), $1, $2, $3) }
        encodeBGRX = { OMTSwiftVMXEncodeBGRX(Self.rawPointer($0), $1, $2, $3) }
        encodeUYVY = { OMTSwiftVMXEncodeUYVY(Self.rawPointer($0), $1, $2, $3) }
        encodeUYVA = { OMTSwiftVMXEncodeUYVA(Self.rawPointer($0), $1, $2, $3) }
        encodeYUY2 = { OMTSwiftVMXEncodeYUY2(Self.rawPointer($0), $1, $2, $3) }
        encodeP216 = { OMTSwiftVMXEncodeP216(Self.rawPointer($0), $1, $2, $3) }
        encodePA16 = { OMTSwiftVMXEncodePA16(Self.rawPointer($0), $1, $2, $3) }
        decodeBGRA = { OMTSwiftVMXDecodeBGRA(Self.rawPointer($0), $1, $2) }
        decodeBGRX = { OMTSwiftVMXDecodeBGRX(Self.rawPointer($0), $1, $2) }
        decodeUYVY = { OMTSwiftVMXDecodeUYVY(Self.rawPointer($0), $1, $2) }
        decodeUYVA = { OMTSwiftVMXDecodeUYVA(Self.rawPointer($0), $1, $2) }
        decodeYUY2 = { OMTSwiftVMXDecodeYUY2(Self.rawPointer($0), $1, $2) }
        decodeP216 = { OMTSwiftVMXDecodeP216(Self.rawPointer($0), $1, $2) }
        decodePA16 = { OMTSwiftVMXDecodePA16(Self.rawPointer($0), $1, $2) }
        decodePreviewBGRA = { OMTSwiftVMXDecodePreviewBGRA(Self.rawPointer($0), $1, $2) }
        decodePreviewBGRX = { OMTSwiftVMXDecodePreviewBGRX(Self.rawPointer($0), $1, $2) }
        decodePreviewUYVY = { OMTSwiftVMXDecodePreviewUYVY(Self.rawPointer($0), $1, $2) }
        decodePreviewUYVA = { OMTSwiftVMXDecodePreviewUYVA(Self.rawPointer($0), $1, $2) }
        decodePreviewYUY2 = { OMTSwiftVMXDecodePreviewYUY2(Self.rawPointer($0), $1, $2) }
        getEncodedPreviewLength = { OMTSwiftVMXGetEncodedPreviewLength(Self.rawPointer($0)) }
    }

    func create(width: Int32, height: Int32, profile: Int32, colorSpace: Int32) -> OpaquePointer? {
        guard let pointer = OMTSwiftVMXCreate(width, height, profile, colorSpace) else {
            return nil
        }
        return OpaquePointer(pointer)
    }

    func saveTo(_ instance: OpaquePointer, _ data: inout Data, _ maxLength: Int32) -> Int32 {
        data.withUnsafeMutableBytes { outputBytes in
            saveToRaw(instance, outputBytes.bindMemory(to: UInt8.self).baseAddress, maxLength)
        }
    }

    private static func rawPointer(_ pointer: OpaquePointer?) -> UnsafeMutableRawPointer? {
        pointer.map { UnsafeMutableRawPointer($0) }
    }
}
