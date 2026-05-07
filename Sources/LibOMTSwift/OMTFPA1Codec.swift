import Foundation

enum OMTFPA1Codec {
    static let sampleSize = 4

    static func encode(_ source: Data, channels: Int, samplesPerChannel: Int) -> (data: Data, activeChannels: UInt32) {
        guard channels > 0, channels <= 32, samplesPerChannel > 0 else {
            return (Data(), 0)
        }

        let channelLength = samplesPerChannel * sampleSize
        var output = Data(capacity: min(source.count, channelLength * channels))
        var activeChannels: UInt32 = 0

        for channel in 0..<channels {
            let start = channel * channelLength
            let end = min(start + channelLength, source.count)
            guard start < end else { continue }

            let slice = source[start..<end]
            if slice.contains(where: { $0 != 0 }) {
                activeChannels |= UInt32(1) << UInt32(channel)
                output.append(slice)
            }
        }

        return (output, activeChannels)
    }

    static func decode(_ source: Data, channels: Int, samplesPerChannel: Int, activeChannels: UInt32) -> Data {
        guard channels > 0, channels <= 32, samplesPerChannel > 0 else {
            return Data()
        }

        let channelLength = samplesPerChannel * sampleSize
        var output = Data(count: channelLength * channels)
        var sourceOffset = 0

        output.withUnsafeMutableBytes { outputBytes in
            guard let outputBase = outputBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            source.withUnsafeBytes { sourceBytes in
                guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
                for channel in 0..<channels {
                    let destination = outputBase.advanced(by: channel * channelLength)
                    let isActive = (activeChannels & (UInt32(1) << UInt32(channel))) != 0
                    if isActive, sourceOffset + channelLength <= source.count {
                        destination.update(from: sourceBase.advanced(by: sourceOffset), count: channelLength)
                        sourceOffset += channelLength
                    } else {
                        destination.initialize(repeating: 0, count: channelLength)
                    }
                }
            }
        }

        return output
    }
}
