import Foundation

struct OMTVideoCodecKey: Equatable {
    var width: Int32
    var height: Int32
    var profile: VMXProfile
    var colorSpace: OMTColorSpace
}

func omtFrameRate(_ numerator: Int32, _ denominator: Int32) -> Int32 {
    guard denominator != 0 else { return numerator }
    return Int32((Double(numerator) / Double(denominator)).rounded())
}

func omtVMXProfile(for quality: OMTQuality) -> VMXProfile {
    switch quality {
    case .low:
        return .omtLowQuality
    case .medium:
        return .omtStandardQuality
    case .high:
        return .omtHighQuality
    case .default:
        return .default
    }
}

func omtVMXEncodeFormat(for codec: OMTCodec, flags: inout OMTVideoFlags) throws -> VMXImageFormat {
    let hasAlpha = flags.contains(.alpha)
    switch codec {
    case .uyvy:
        return .uyvy
    case .yuy2:
        return .yuy2
    case .nv12:
        return .nv12
    case .yv12:
        return .yv12
    case .bgra:
        return hasAlpha ? .bgra : .bgrx
    case .uyva:
        return hasAlpha ? .uyva : .uyvy
    case .p216:
        flags.insert(.highBitDepth)
        return .p216
    case .pa16:
        flags.insert(.highBitDepth)
        return hasAlpha ? .pa16 : .p216
    case .vmx1, .fpa1:
        throw OMTError.unsupportedCodec(codec)
    }
}

func omtPreferredDecodeFormat(
    preferred: OMTPreferredVideoFormat,
    flags: OMTVideoFlags,
    preview: Bool
) -> (codec: OMTCodec, vmxFormat: VMXImageFormat, bytesPerRow: Int32, lengthMultiplier: Int) {
    let alpha = flags.contains(.alpha)
    let highBitDepth = flags.contains(.highBitDepth)

    if preferred == .bgra || (preferred == .uyvyOrBGRA && alpha) {
        return (.bgra, alpha ? .bgra : .bgrx, 4, 1)
    }

    if alpha && (preferred == .uyvyOrUYVA || preferred == .uyvyOrUYVAOrP216OrPA16) {
        return (.uyva, .uyva, 2, 1)
    }

    if !preview && (preferred == .p216 || (preferred == .uyvyOrUYVAOrP216OrPA16 && highBitDepth)) {
        if alpha && preferred != .p216 {
            return (.pa16, .pa16, 2, 3)
        }
        return (.p216, .p216, 2, 2)
    }

    return (.uyvy, .uyvy, 2, 1)
}

func omtVideoPayloadLength(codec: OMTCodec, width: Int32, height: Int32, stride: Int32) -> Int {
    let rows = Int(height)
    let base = Int(stride) * rows
    switch codec {
    case .uyva:
        return base + Int(width) * rows
    case .p216:
        return base * 2
    case .pa16:
        return base * 3
    default:
        return base
    }
}

func omtPreviewSize(width: Int32, height: Int32, interlaced: Bool) -> (width: Int32, height: Int32) {
    var previewWidth = max(1, width / 8)
    var previewHeight = max(1, height / 8)
    if previewWidth % 2 != 0 {
        previewWidth += 1
    }
    if interlaced, previewHeight % 2 != 0 {
        previewHeight = max(1, previewHeight - 1)
    }
    return (previewWidth, previewHeight)
}
