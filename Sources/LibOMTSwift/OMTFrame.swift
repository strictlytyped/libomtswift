import Foundation

public struct OMTFrame: Equatable, Sendable {
    public static let headerLength = 16
    public static let videoExtendedHeaderLength = 32
    public static let audioExtendedHeaderLength = 24
    public static let HeaderLength = headerLength
    public static let ExtendedHeaderVideo = videoExtendedHeaderLength
    public static let ExtendedHeaderAudio = audioExtendedHeaderLength

    public var frameType: OMTFrameType
    public var timestamp: Int64
    public var videoFormat: OMTVideoFormatDescription?
    public var audioFormat: OMTAudioFormatDescription?
    public var payload: Data
    public var metadata: String?
    public var previewPayloadLength: Int?

    public init(
        frameType: OMTFrameType,
        timestamp: Int64 = 0,
        videoFormat: OMTVideoFormatDescription? = nil,
        audioFormat: OMTAudioFormatDescription? = nil,
        payload: Data = Data(),
        metadata: String? = nil,
        previewPayloadLength: Int? = nil
    ) {
        self.frameType = frameType
        self.timestamp = timestamp
        self.videoFormat = videoFormat
        self.audioFormat = audioFormat
        self.payload = payload
        self.metadata = metadata
        self.previewPayloadLength = previewPayloadLength
    }

    public static func metadata(_ metadata: OMTMetadata) -> OMTFrame {
        var payload = Data(metadata.xml.utf8)
        payload.append(0)
        return OMTFrame(frameType: .metadata, timestamp: metadata.timestamp, payload: payload, metadata: metadata.xml)
    }

    public var extendedHeaderLength: Int {
        if frameType.contains(.video) {
            return Self.videoExtendedHeaderLength
        }
        if frameType.contains(.audio) {
            return Self.audioExtendedHeaderLength
        }
        return 0
    }

    public var HeaderLength: Int { Self.headerLength }
    public var ExtendedHeaderLength: Int { extendedHeaderLength }
    public var Length: Int { encodedLength }
    public var FrameType: OMTFrameType {
        get { frameType }
        set { frameType = newValue }
    }
    public var Timestamp: Int64 {
        get { timestamp }
        set { timestamp = newValue }
    }
    public var MetadataLength: Int { metadataData.count }

    public var metadataData: Data {
        guard let metadata else { return Data() }
        var data = Data(metadata.utf8)
        data.append(0)
        return data
    }

    public var encodedLength: Int {
        Self.headerLength + encodedDataLength(preview: false)
    }

    public func encodedLength(preview: Bool) -> Int {
        Self.headerLength + encodedDataLength(preview: preview)
    }

    private func encodedDataLength(preview: Bool) -> Int {
        let payload = encodedPayload
        let metadataData = frameType == .metadata ? Data() : metadataData
        if preview, let previewPayloadLength {
            return extendedHeaderLength + min(previewPayloadLength, payload.count) + metadataData.count
        }
        return extendedHeaderLength + payload.count + metadataData.count
    }

    private var encodedPayload: Data {
        if frameType == .metadata, payload.isEmpty, let metadata {
            var data = Data(metadata.utf8)
            data.append(0)
            return data
        }
        return payload
    }

    public func encoded(preview: Bool = false) throws -> Data {
        if frameType.contains(.video), videoFormat == nil {
            throw OMTError.invalidFrameLength
        }
        if frameType.contains(.audio), audioFormat == nil {
            throw OMTError.invalidFrameLength
        }

        let payload = encodedPayload
        let metadataData = frameType == .metadata ? Data() : metadataData
        let usePreview = preview && previewPayloadLength != nil
        let payloadLength = usePreview ? min(previewPayloadLength ?? payload.count, payload.count) : payload.count
        var writer = OMTBinaryWriter(capacity: Self.headerLength + extendedHeaderLength + payloadLength + metadataData.count)
        writer.writeUInt8(1)
        writer.writeUInt8(frameType.rawValue)
        writer.writeInt64(timestamp)
        writer.writeUInt16(UInt16(metadataData.count))
        writer.writeInt32(Int32(extendedHeaderLength + payloadLength + metadataData.count))

        if var videoFormat {
            if usePreview {
                videoFormat.flags.insert(.preview)
            }
            writer.writeInt32(videoFormat.codec.rawValue)
            writer.writeInt32(videoFormat.width)
            writer.writeInt32(videoFormat.height)
            writer.writeInt32(videoFormat.frameRateNumerator)
            writer.writeInt32(videoFormat.frameRateDenominator)
            writer.writeFloat32(videoFormat.aspectRatio)
            writer.writeInt32(videoFormat.flags.rawValue)
            writer.writeInt32(videoFormat.colorSpace.rawValue)
        } else if let audioFormat {
            writer.writeInt32(audioFormat.codec.rawValue)
            writer.writeInt32(audioFormat.sampleRate)
            writer.writeInt32(audioFormat.samplesPerChannel)
            writer.writeInt32(audioFormat.channels)
            writer.writeUInt32(audioFormat.activeChannels)
            writer.writeInt32(audioFormat.reserved)
        }

        writer.writeData(payload.prefix(payloadLength))
        writer.writeData(metadataData)
        return writer.data
    }

    public func Encoded() throws -> Data {
        try encoded()
    }

    public static func decode(_ data: Data) throws -> OMTFrame {
        guard data.count >= Self.headerLength else { throw OMTError.invalidFrameLength }
        var reader = OMTBinaryReader(data: data)
        let version = try reader.readUInt8()
        guard version == 1 else { throw OMTError.invalidFrameVersion(version) }

        let frameTypeValue = try reader.readUInt8()
        let frameType = OMTFrameType(rawValue: frameTypeValue)
        guard !frameType.isEmpty else { throw OMTError.invalidFrameType(frameTypeValue) }

        let timestamp = try reader.readInt64()
        let metadataLength = Int(try reader.readUInt16())
        let dataLength = Int(try reader.readInt32())
        guard dataLength >= 0, Self.headerLength + dataLength <= data.count else {
            throw OMTError.invalidFrameLength
        }

        var videoFormat: OMTVideoFormatDescription?
        var audioFormat: OMTAudioFormatDescription?
        var extendedHeaderLength = 0

        if frameType.contains(.video) {
            extendedHeaderLength = Self.videoExtendedHeaderLength
            let codecRaw = try reader.readInt32()
            guard let codec = OMTCodec(rawValue: codecRaw) else { throw OMTError.invalidCodec(codecRaw) }
            let width = try reader.readInt32()
            let height = try reader.readInt32()
            let frameRateNumerator = try reader.readInt32()
            let frameRateDenominator = try reader.readInt32()
            let aspectRatio = try reader.readFloat32()
            let flags = OMTVideoFlags(rawValue: try reader.readInt32())
            let colorRaw = try reader.readInt32()
            let colorSpace = OMTColorSpace(rawValue: colorRaw) ?? .undefined
            videoFormat = OMTVideoFormatDescription(
                codec: codec,
                width: width,
                height: height,
                frameRateNumerator: frameRateNumerator,
                frameRateDenominator: frameRateDenominator,
                aspectRatio: aspectRatio,
                flags: flags,
                colorSpace: colorSpace
            )
        } else if frameType.contains(.audio) {
            extendedHeaderLength = Self.audioExtendedHeaderLength
            let codecRaw = try reader.readInt32()
            guard let codec = OMTCodec(rawValue: codecRaw) else { throw OMTError.invalidCodec(codecRaw) }
            audioFormat = OMTAudioFormatDescription(
                codec: codec,
                sampleRate: try reader.readInt32(),
                samplesPerChannel: try reader.readInt32(),
                channels: try reader.readInt32(),
                activeChannels: try reader.readUInt32(),
                reserved: try reader.readInt32()
            )
        }

        guard dataLength >= extendedHeaderLength + metadataLength else {
            throw OMTError.invalidFrameLength
        }

        let payloadLength = dataLength - extendedHeaderLength - metadataLength
        let payloadStart = Self.headerLength + extendedHeaderLength
        let payloadEnd = payloadStart + payloadLength
        let payload = data[payloadStart..<payloadEnd]

        var metadata: String?
        if frameType == .metadata {
            var metadataBytes = Data(payload)
            if metadataBytes.last == 0 {
                metadataBytes.removeLast()
            }
            metadata = String(data: metadataBytes, encoding: .utf8)
        } else if metadataLength > 0 {
            let metadataStart = payloadEnd
            let metadataEnd = metadataStart + metadataLength
            var metadataBytes = data[metadataStart..<metadataEnd]
            if metadataBytes.last == 0 {
                metadataBytes.removeLast()
            }
            metadata = String(data: metadataBytes, encoding: .utf8)
        }

        return OMTFrame(
            frameType: frameType,
            timestamp: timestamp,
            videoFormat: videoFormat,
            audioFormat: audioFormat,
            payload: Data(payload),
            metadata: metadata,
            previewPayloadLength: videoFormat?.flags.contains(.preview) == true ? payloadLength : nil
        )
    }

    public static func Decode(_ data: Data) throws -> OMTFrame {
        try decode(data)
    }
}
