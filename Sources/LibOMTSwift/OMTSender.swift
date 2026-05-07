import Foundation
import Network

public final class OMTSender {
    public let name: String
    public private(set) var address: OMTAddress
    public var onMetadata: ((OMTMetadata) -> Void)?
    public var onError: ((Error) -> Void)?

    public var url: String { address.url }
    public var connectionCount: Int { lock.withLock { channels.count } }
    public var port: Int { address.port }

    public var quality: OMTQuality {
        get { lock.withLock { configuredQuality } }
        set { lock.withLock { configuredQuality = newValue } }
    }

    public var Port: Int { port }
    public var Address: String { address.fullName }
    public var URL: String { url }
    public var Connections: Int { connectionCount }
    public var Quality: OMTQuality {
        get { quality }
        set { quality = newValue }
    }

    private let queue = DispatchQueue(label: "com.strictly.omtswift.sender")
    private let lock = NSLock()
    private let listener: NWListener
    private let vmxSymbolProvider: VMXSymbolProvider
    private var videoClock = OMTClock()
    private var audioClock = OMTClock(audio: true)
    private var netService: NetService?
    private var channels: [OMTChannel] = []
    private var configuredQuality: OMTQuality
    private var senderInfoXML: String?
    private var connectionMetadata: [String] = []
    private var tally = OMTTally()
    private var videoCodec: OMTVMXCodec?
    private var videoCodecKey: OMTVideoCodecKey?

    public init(
        name: String,
        quality: OMTQuality = .default,
        portRange: ClosedRange<Int> = OMTConstants.networkPortStart...OMTConstants.networkPortEnd,
        vmxSymbolProvider: VMXSymbolProvider = .process
    ) throws {
        self.name = name
        self.configuredQuality = quality
        self.vmxSymbolProvider = vmxSymbolProvider

        var selectedListener: NWListener?
        var selectedPort = 0
        var lastError: Error?
        for port in portRange {
            do {
                selectedListener = try NWListener(using: omtTCPParameters(), on: NWEndpoint.Port(omtPort: port))
                selectedPort = port
                break
            } catch {
                lastError = error
            }
        }

        guard let selectedListener else {
            throw lastError ?? OMTError.invalidAddress("No available OMT port in \(portRange)")
        }

        self.listener = selectedListener
        self.address = OMTAddress(name: name, port: selectedPort, host: ProcessInfo.processInfo.hostName)

        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.onError?(error)
            }
        }
        listener.start(queue: queue)

        let service = NetService(domain: "local.", type: OMTConstants.serviceType, name: address.fullName, port: Int32(selectedPort))
        service.publish()
        self.netService = service
    }

    deinit {
        stop()
    }

    public func stop() {
        netService?.stop()
        listener.cancel()
        let current = lock.withLock { () -> [OMTChannel] in
            let current = channels
            channels.removeAll()
            return current
        }
        current.forEach { $0.close() }
    }

    public func close() {
        stop()
    }

    public func Dispose() {
        stop()
    }

    public func setSenderInformation(_ senderInfo: OMTSenderInfo?) {
        let xml = senderInfo?.xml
        lock.withLock {
            senderInfoXML = xml
        }
        if let xml {
            _ = try? sendMetadata(OMTMetadata(xml: xml))
        }
    }

    public func SetSenderInformation(_ senderInfo: OMTSenderInfo?) {
        setSenderInformation(senderInfo)
    }

    public func addConnectionMetadata(_ xml: String) {
        lock.withLock {
            connectionMetadata.append(xml)
        }
    }

    public func AddConnectionMetadata(_ xml: String) {
        addConnectionMetadata(xml)
    }

    public func clearConnectionMetadata() {
        lock.withLock {
            connectionMetadata.removeAll()
        }
    }

    public func ClearConnectionMetadata() {
        clearConnectionMetadata()
    }

    public func setRedirect(_ newAddress: String?) {
        let xml = OMTRedirect.toXML(newAddress)
        _ = try? sendMetadata(OMTMetadata(xml: xml))
    }

    public func SetRedirect(_ newAddress: String?) {
        setRedirect(newAddress)
    }

    public func setTally(_ tally: OMTTally) {
        lock.withLock {
            self.tally = tally
        }
        _ = try? sendMetadata(OMTMetadata(xml: OMTMetadataCommand.tally(tally)))
    }

    public func SetTally(_ tally: OMTTally) {
        setTally(tally)
    }

    @discardableResult
    public func sendMetadata(_ metadata: OMTMetadata) throws -> Int {
        let frame = OMTFrame.metadata(metadata)
        return try sendFrame(frame, metadataOnly: true)
    }

    @discardableResult
    public func send(_ frame: OMTMediaFrame) throws -> Int {
        if frame.type == .metadata {
            let xml = frame.frameMetadata ?? String(data: frame.data.dropLastNull(), encoding: .utf8) ?? ""
            return try sendMetadata(OMTMetadata(timestamp: frame.timestamp, xml: xml))
        }
        if frame.type == .video {
            return try sendVideo(frame)
        }
        if frame.type == .audio {
            return try sendAudio(frame)
        }
        return 0
    }

    @discardableResult
    public func Send(_ frame: OMTMediaFrame) throws -> Int {
        try send(frame)
    }

    public func getVideoStatistics() -> OMTStatistics {
        aggregateStatistics(for: .video)
    }

    public func GetVideoStatistics() -> OMTStatistics {
        getVideoStatistics()
    }

    public func getAudioStatistics() -> OMTStatistics {
        aggregateStatistics(for: .audio)
    }

    public func GetAudioStatistics() -> OMTStatistics {
        getAudioStatistics()
    }

    private func accept(_ connection: NWConnection) {
        let channel = OMTChannel(connection: connection, receiveFrameType: .metadata, queue: queue)
        channel.onReady = { [weak self, weak channel] in
            guard let self, let channel else { return }
            let (senderInfoXML, connectionMetadata, tally) = self.lock.withLock {
                (self.senderInfoXML, self.connectionMetadata, self.tally)
            }
            if let senderInfoXML {
                _ = try? channel.sendMetadataXML(senderInfoXML, timestamp: 0)
            }
            for xml in connectionMetadata {
                _ = try? channel.sendMetadataXML(xml, timestamp: 0)
            }
            _ = try? channel.sendMetadataXML(OMTMetadataCommand.tally(tally), timestamp: 0)
        }
        channel.onMetadata = { [weak self] metadata in
            self?.onMetadata?(metadata)
        }
        channel.onError = { [weak self] error in
            self?.onError?(error)
        }
        channel.onClose = { [weak self] channel in
            self?.remove(channel)
        }

        lock.withLock {
            channels.append(channel)
        }
        channel.start()
    }

    private func remove(_ channel: OMTChannel) {
        lock.withLock {
            channels.removeAll { $0 === channel }
        }
    }

    private func sendFrame(_ frame: OMTFrame, metadataOnly: Bool = false) throws -> Int {
        let current = lock.withLock { channels }
        var total = 0
        for channel in current {
            if metadataOnly, !channel.isSubscribed(to: .metadata) {
                continue
            }
            total += try channel.send(frame)
        }
        return total
    }

    private func currentQualitySuggestion() -> OMTQuality {
        let configured = lock.withLock { configuredQuality }
        if configured != .default {
            return configured
        }
        let current = lock.withLock { channels }
        return current.map(\.suggestedQuality).max { $0.rawValue < $1.rawValue } ?? .default
    }

    private func aggregateStatistics(for frameType: OMTFrameType) -> OMTStatistics {
        let current = lock.withLock { channels }
        return current.reduce(into: OMTStatistics()) { result, channel in
            guard channel.isSubscribed(to: frameType) else { return }
            let stats = channel.statistics
            result.bytesSent += stats.bytesSent
            result.bytesReceived += stats.bytesReceived
            result.bytesSentSinceLast += stats.bytesSentSinceLast
            result.bytesReceivedSinceLast += stats.bytesReceivedSinceLast
            result.frames += stats.frames
            result.framesSinceLast += stats.framesSinceLast
            result.framesDropped += stats.framesDropped
            result.codecTime += stats.codecTime
            result.codecTimeSinceLast += stats.codecTimeSinceLast
        }
    }

    private func codec(width: Int32, height: Int32, colorSpace: OMTColorSpace) throws -> OMTVMXCodec {
        let profile = omtVMXProfile(for: currentQualitySuggestion())
        let key = OMTVideoCodecKey(width: width, height: height, profile: profile, colorSpace: colorSpace)
        if let videoCodec, videoCodecKey == key {
            return videoCodec
        }
        let newCodec = try OMTVMXCodec(width: width, height: height, profile: profile, colorSpace: colorSpace, symbolProvider: vmxSymbolProvider)
        videoCodec = newCodec
        videoCodecKey = key
        return newCodec
    }

    private func sendVideo(_ frame: OMTMediaFrame) throws -> Int {
        guard !frame.data.isEmpty, frame.width >= 16, frame.height >= 16 else {
            return 0
        }

        var frame = frame
        if frame.timestamp == -1 {
            videoClock.process(&frame)
        }
        var flags = frame.flags
        var payload = frame.data
        var previewPayloadLength: Int?
        if frame.codec != .vmx1 {
            let format = try omtVMXEncodeFormat(for: frame.codec, flags: &flags)
            let codec = try codec(width: frame.width, height: frame.height, colorSpace: frame.colorSpace)
            payload = try codec.encode(
                format,
                source: frame.data,
                stride: frame.stride,
                interlaced: flags.contains(.interlaced),
                maxOutputLength: OMTConstants.videoMaxSize
            )
            let previewLength = codec.encodedPreviewLength()
            if previewLength > 0 {
                previewPayloadLength = Int(previewLength)
            }
        }

        let format = OMTVideoFormatDescription(
            codec: .vmx1,
            width: frame.width,
            height: frame.height,
            frameRateNumerator: frame.frameRateNumerator,
            frameRateDenominator: frame.frameRateDenominator,
            aspectRatio: frame.aspectRatio,
            flags: flags,
            colorSpace: frame.colorSpace
        )
        let omtFrame = OMTFrame(
            frameType: .video,
            timestamp: frame.timestamp == 0 ? videoClock.timestamp : frame.timestamp,
            videoFormat: format,
            payload: payload,
            metadata: frame.frameMetadata,
            previewPayloadLength: previewPayloadLength
        )
        return try sendFrame(omtFrame)
    }

    private func sendAudio(_ frame: OMTMediaFrame) throws -> Int {
        guard !frame.data.isEmpty, frame.channels > 0, frame.channels <= 32, frame.samplesPerChannel > 0 else {
            return 0
        }

        var frame = frame
        if frame.timestamp == -1 {
            audioClock.process(&frame)
        }
        let encoded = OMTFPA1Codec.encode(frame.data, channels: Int(frame.channels), samplesPerChannel: Int(frame.samplesPerChannel))
        let format = OMTAudioFormatDescription(
            codec: .fpa1,
            sampleRate: frame.sampleRate,
            samplesPerChannel: frame.samplesPerChannel,
            channels: frame.channels,
            activeChannels: encoded.activeChannels
        )
        let omtFrame = OMTFrame(
            frameType: .audio,
            timestamp: frame.timestamp == 0 ? audioClock.timestamp : frame.timestamp,
            audioFormat: format,
            payload: encoded.data,
            metadata: frame.frameMetadata
        )
        return try sendFrame(omtFrame)
    }
}

private extension Data {
    func dropLastNull() -> Data {
        var copy = self
        if copy.last == 0 {
            copy.removeLast()
        }
        return copy
    }
}
