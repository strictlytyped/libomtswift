import Foundation

public enum OMTUtils {
    public static func stringToUTF8Data(_ string: String, nullTerminated: Bool = true) -> Data {
        var data = Data(string.utf8)
        if nullTerminated {
            data.append(0)
        }
        return data
    }

    public static func utf8String(from data: Data, maxLength: Int? = nil) -> String {
        let prefix = data.prefix(maxLength ?? data.count)
        let bytes = prefix.split(separator: 0, maxSplits: 1, omittingEmptySubsequences: false).first ?? []
        return String(decoding: bytes, as: UTF8.self)
    }

    public static func toFrameRate(_ frameRateN: Int32, _ frameRateD: Int32) -> Float {
        guard frameRateD != 0 else { return 0 }
        let value = Double(frameRateN) / Double(frameRateD)
        return Float((value * 100).rounded() / 100)
    }

    public static func toFrameRate(_ frameRateN: Int, _ frameRateD: Int) -> Float {
        toFrameRate(Int32(frameRateN), Int32(frameRateD))
    }

    public static func fromFrameRate(_ fps: Float) -> (numerator: Int32, denominator: Int32) {
        switch Double(fps).rounded(toPlaces: 3) {
        case 29.97:
            return (30000, 1001)
        case 59.94:
            return (60000, 1001)
        case 119.88:
            return (120000, 1001)
        case 239.76:
            return (240000, 1001)
        case 23.98, 23.976:
            return (24000, 1001)
        default:
            return (Int32(fps), 1)
        }
    }

    public static func fromFrameRate(_ fps: Float, frameRateN: inout Int32, frameRateD: inout Int32) {
        let values = fromFrameRate(fps)
        frameRateN = values.numerator
        frameRateD = values.denominator
    }

    public static func interleavedToPlanarAudio32F32F(
        numSamples: Int,
        channels: Int,
        sampleStride: Int,
        source: [Float],
        destination: inout [Float]
    ) {
        var sourceOffset = 0
        for sample in 0..<numSamples {
            for channel in 0..<channels {
                let destinationIndex = sampleStride * channel + sample
                guard sourceOffset < source.count, destinationIndex < destination.count else { return }
                destination[destinationIndex] = source[sourceOffset]
                sourceOffset += 1
            }
        }
    }

    public static func interleavedToPlanarAudio1632F(
        numSamples: Int,
        channels: Int,
        sampleStride: Int,
        source: [Int16],
        destination: inout [Float]
    ) {
        var sourceOffset = 0
        for sample in 0..<numSamples {
            for channel in 0..<channels {
                let destinationIndex = sampleStride * channel + sample
                guard sourceOffset < source.count, destinationIndex < destination.count else { return }
                destination[destinationIndex] = Float(source[sourceOffset]) / Float(Int16.max)
                sourceOffset += 1
            }
        }
    }

    public static func StringToPtrUTF8(_ string: String) -> Data {
        stringToUTF8Data(string)
    }

    public static func PtrToStringUTF8(_ data: Data, maxLength: Int? = nil) -> String {
        utf8String(from: data, maxLength: maxLength)
    }

    public static func ToFrameRate(_ frameRateN: Int32, _ frameRateD: Int32) -> Float {
        toFrameRate(frameRateN, frameRateD)
    }

    public static func FromFrameRate(_ fps: Float) -> (numerator: Int32, denominator: Int32) {
        fromFrameRate(fps)
    }

    public static func InterleavedToPlanarAudio32F32F(
        numSamples: Int,
        channels: Int,
        sampleStride: Int,
        source: [Float],
        destination: inout [Float]
    ) {
        interleavedToPlanarAudio32F32F(
            numSamples: numSamples,
            channels: channels,
            sampleStride: sampleStride,
            source: source,
            destination: &destination
        )
    }

    public static func InterleavedToPlanarAudio1632F(
        numSamples: Int,
        channels: Int,
        sampleStride: Int,
        source: [Int16],
        destination: inout [Float]
    ) {
        interleavedToPlanarAudio1632F(
            numSamples: numSamples,
            channels: channels,
            sampleStride: sampleStride,
            source: source,
            destination: &destination
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
