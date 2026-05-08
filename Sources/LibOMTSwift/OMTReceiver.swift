import Foundation
import Network

public final class OMTReceiver {
    public let frames: AsyncStream<OMTMediaFrame>
    public var onFrame: ((OMTMediaFrame) -> Void)?
    public var onMetadata: ((OMTMetadata) -> Void)?
    public var onError: ((Error) -> Void)?

    public private(set) var address: OMTAddress
    public private(set) var redirectAddress: String?
    public private(set) var senderInfo: OMTSenderInfo?
    public var isConnected: Bool {
        lock.withLock { isConnectedLocked() }
    }

    public var Address: String { address.url }
    public var RedirectAddress: String? { redirectAddress }

    private let queue = DispatchQueue(label: "dev.strictlytyped.omtswift.receiver")
    private let lock = NSLock()
    private let frameContinuation: AsyncStream<OMTMediaFrame>.Continuation
    private let preferredVideoFormat: OMTPreferredVideoFormat
    private let vmxSymbolProvider: VMXSymbolProvider
    private var receiveFlags: OMTReceiveFlags
    private var frameTypes: OMTFrameType
    private var videoChannel: OMTChannel?
    private var audioChannel: OMTChannel?
    private var videoCodec: OMTVMXCodec?
    private var videoCodecKey: OMTVideoCodecKey?
    private var tally = OMTTally()
    private var suggestedQuality = OMTQuality.default
    private var closed = false
    private var lastBeginConnect = Date.distantPast
    private var reconnectWorkItem: DispatchWorkItem?
    private let reconnectInterval: TimeInterval = 1.0

    public convenience init(
        url: String,
        frameTypes: OMTFrameType,
        preferredVideoFormat: OMTPreferredVideoFormat = .uyvy,
        flags: OMTReceiveFlags = [],
        vmxSymbolProvider: VMXSymbolProvider = .process
    ) throws {
        guard let address = OMTAddress.parseURL(url) else {
            throw OMTError.invalidAddress(url)
        }
        try self.init(
            address: address,
            frameTypes: frameTypes,
            preferredVideoFormat: preferredVideoFormat,
            flags: flags,
            vmxSymbolProvider: vmxSymbolProvider
        )
    }

    public convenience init(
        _ address: String,
        frameTypes: OMTFrameType,
        format: OMTPreferredVideoFormat = .uyvy,
        flags: OMTReceiveFlags = []
    ) throws {
        if let parsed = OMTAddress.parseURL(address) {
            try self.init(address: parsed, frameTypes: frameTypes, preferredVideoFormat: format, flags: flags)
        } else if let discovered = OMTDiscovery.shared.find(address) {
            try self.init(address: discovered, frameTypes: frameTypes, preferredVideoFormat: format, flags: flags)
        } else {
            throw OMTError.invalidAddress(address)
        }
    }

    public init(
        address: OMTAddress,
        frameTypes: OMTFrameType,
        preferredVideoFormat: OMTPreferredVideoFormat = .uyvy,
        flags: OMTReceiveFlags = [],
        vmxSymbolProvider: VMXSymbolProvider = .process
    ) throws {
        var continuation: AsyncStream<OMTMediaFrame>.Continuation!
        self.frames = AsyncStream(bufferingPolicy: .bufferingNewest(3)) { continuation = $0 }
        self.frameContinuation = continuation
        self.address = address
        self.frameTypes = frameTypes
        self.preferredVideoFormat = preferredVideoFormat
        self.receiveFlags = flags
        self.vmxSymbolProvider = vmxSymbolProvider
        connect()
    }

    deinit {
        close()
    }

    public func close() {
        frameContinuation.finish()
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        let current = lock.withLock { () -> [OMTChannel] in
            closed = true
            let current = [videoChannel, audioChannel].compactMap { $0 }
            videoChannel = nil
            audioChannel = nil
            return current
        }
        current.forEach { $0.close() }
    }

    public func Dispose() {
        close()
    }

    public func isConnectedNow() -> Bool {
        isConnected
    }

    public func IsConnected() -> Bool {
        isConnected
    }

    public func checkConnection() {
        beginConnect()
    }

    public func CheckConnection() {
        checkConnection()
    }

    public func setTally(_ tally: OMTTally) {
        lock.withLock {
            self.tally = tally
        }
        sendControl(OMTMetadataCommand.tally(tally))
    }

    public func SetTally(_ tally: OMTTally) {
        setTally(tally)
    }

    public func setSuggestedQuality(_ quality: OMTQuality) {
        lock.withLock {
            suggestedQuality = quality
        }
        sendControl(OMTMetadataCommand.suggestedQuality(quality))
    }

    public func SetSuggestedQuality(_ quality: OMTQuality) {
        setSuggestedQuality(quality)
    }

    public func setFlags(_ flags: OMTReceiveFlags) {
        lock.withLock {
            receiveFlags = flags
        }
        sendControl(flags.contains(.preview) ? OMTMetadataCommand.previewVideoOn : OMTMetadataCommand.previewVideoOff)
    }

    public func SetFlags(_ flags: OMTReceiveFlags) {
        setFlags(flags)
    }

    @discardableResult
    public func sendMetadata(_ metadata: OMTMetadata) -> Int {
        checkConnection()
        do {
            return try controlChannel()?.sendMetadataXML(metadata.xml, timestamp: metadata.timestamp) ?? 0
        } catch {
            onError?(error)
            return 0
        }
    }

    @discardableResult
    public func send(_ metadata: OMTMediaFrame) -> Int {
        guard metadata.type == .metadata, let value = OMTMetadata.fromMediaFrame(metadata) else {
            return 0
        }
        return sendMetadata(value)
    }

    @discardableResult
    public func Send(_ metadata: OMTMediaFrame) -> Int {
        send(metadata)
    }

    public func getSenderInformation() -> OMTSenderInfo? {
        senderInfo ?? lock.withLock { videoChannel?.senderInfo ?? audioChannel?.senderInfo }
    }

    public func GetSenderInformation() -> OMTSenderInfo? {
        getSenderInformation()
    }

    public func getRemoteEndpoint() -> (host: String, port: Int) {
        let current = resolvedAddress()
        return (current.host ?? current.machineName, current.port)
    }

    public func GetRemoteEndPoint() -> (host: String, port: Int) {
        getRemoteEndpoint()
    }

    public func getVideoStatistics() -> OMTStatistics {
        lock.withLock { videoChannel?.statistics ?? OMTStatistics() }
    }

    public func GetVideoStatistics() -> OMTStatistics {
        getVideoStatistics()
    }

    public func getAudioStatistics() -> OMTStatistics {
        lock.withLock { audioChannel?.statistics ?? OMTStatistics() }
    }

    public func GetAudioStatistics() -> OMTStatistics {
        getAudioStatistics()
    }

    private func connect() {
        beginConnect(force: true)
    }

    private func beginConnect(force: Bool = false) {
        let targetAddress = resolvedAddress()
        let now = Date()
        let connectionPlan = lock.withLock { () -> (current: [OMTChannel], shouldStart: Bool) in
            guard !closed else { return ([], false) }
            if !force, isConnectedLocked() || hasPendingRequiredChannelsLocked() {
                return ([], false)
            }

            let elapsed = now.timeIntervalSince(lastBeginConnect)
            if !force, elapsed < reconnectInterval {
                scheduleReconnectLocked(after: reconnectInterval - elapsed)
                return ([], false)
            }

            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            lastBeginConnect = now
            let current = [videoChannel, audioChannel].compactMap { $0 }
            videoChannel = nil
            audioChannel = nil
            return (current, true)
        }
        guard connectionPlan.shouldStart else { return }
        connectionPlan.current.forEach { $0.close() }

        let newVideoChannel: OMTChannel?
        let newAudioChannel: OMTChannel?
        if frameTypes.contains(.video) {
            newVideoChannel = makeChannel(type: .video, address: targetAddress)
        } else if frameTypes == .metadata {
            newVideoChannel = makeChannel(type: .metadata, address: targetAddress)
        } else {
            newVideoChannel = nil
        }
        if frameTypes.contains(.audio) {
            newAudioChannel = makeChannel(type: .audio, address: targetAddress)
        } else {
            newAudioChannel = nil
        }

        let channelsToClose = lock.withLock { () -> [OMTChannel] in
            guard !closed else {
                return [newVideoChannel, newAudioChannel].compactMap { $0 }
            }
            videoChannel = newVideoChannel
            audioChannel = newAudioChannel
            if !hasPendingRequiredChannelsLocked() {
                scheduleReconnectLocked(after: reconnectInterval)
            }
            return []
        }
        channelsToClose.forEach { $0.close() }
        newVideoChannel?.start()
        newAudioChannel?.start()
    }

    private func closeExistingChannels() {
        let current = lock.withLock { () -> [OMTChannel] in
            let current = [videoChannel, audioChannel].compactMap { $0 }
            videoChannel = nil
            audioChannel = nil
            return current
        }
        current.forEach { $0.close() }
    }

    private func makeChannel(type: OMTFrameType, address: OMTAddress) -> OMTChannel? {
        let host = address.host ?? address.machineName
        do {
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: try NWEndpoint.Port(omtPort: address.port),
                using: omtTCPParameters()
            )
            let channel = OMTChannel(connection: connection, receiveFrameType: type, queue: queue)
            channel.onReady = { [weak self, weak channel] in
                guard let self, let channel else { return }
                self.subscribe(channel, type: type)
            }
            channel.onFrame = { [weak self] frame in
                self?.receive(frame)
            }
            channel.onMetadata = { [weak self] metadata in
                self?.receive(metadata)
            }
            channel.onError = { [weak self] error in
                self?.onError?(error)
            }
            channel.onClose = { [weak self] channel in
                self?.remove(channel)
            }
            return channel
        } catch {
            onError?(error)
            return nil
        }
    }

    private func resolvedAddress() -> OMTAddress {
        if let redirectAddress, !redirectAddress.isEmpty {
            if let parsed = OMTAddress.parseURL(redirectAddress) {
                return parsed
            }
            if let discovered = OMTDiscovery.shared.find(redirectAddress) {
                return discovered
            }
        }
        if let discovered = OMTDiscovery.shared.find(address.fullName), !discovered.removed {
            return discovered
        }
        return address
    }

    private func isConnectedLocked() -> Bool {
        if frameTypes.isEmpty { return true }
        if frameTypes.contains(.video) || frameTypes == .metadata {
            guard videoChannel?.isConnected == true else { return false }
        }
        if frameTypes.contains(.audio) {
            guard audioChannel?.isConnected == true else { return false }
        }
        return true
    }

    private func hasPendingRequiredChannelsLocked() -> Bool {
        if frameTypes.isEmpty { return true }
        if frameTypes.contains(.video) || frameTypes == .metadata {
            guard videoChannel != nil else { return false }
        }
        if frameTypes.contains(.audio) {
            guard audioChannel != nil else { return false }
        }
        return true
    }

    private func scheduleReconnectLocked(after delay: TimeInterval) {
        guard !closed, reconnectWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.beginConnect()
        }
        reconnectWorkItem = workItem
        queue.asyncAfter(deadline: .now() + max(0, delay), execute: workItem)
    }

    private func subscribe(_ channel: OMTChannel, type: OMTFrameType) {
        do {
            if type == .video {
                try channel.sendMetadataXML(OMTMetadataCommand.subscribeMetadata)
                if receiveFlags.contains(.preview) {
                    try channel.sendMetadataXML(OMTMetadataCommand.previewVideoOn)
                }
                try channel.sendMetadataXML(OMTMetadataCommand.subscribeVideo)
                try channel.sendMetadataXML(OMTMetadataCommand.suggestedQuality(suggestedQuality))
                try channel.sendMetadataXML(OMTMetadataCommand.tally(tally))
            } else if type == .audio {
                if !frameTypes.contains(.video) {
                    try channel.sendMetadataXML(OMTMetadataCommand.subscribeMetadata)
                }
                try channel.sendMetadataXML(OMTMetadataCommand.subscribeAudio)
            } else if type == .metadata {
                try channel.sendMetadataXML(OMTMetadataCommand.subscribeMetadata)
            }
        } catch {
            onError?(error)
        }
    }

    private func remove(_ channel: OMTChannel) {
        let shouldReconnect = lock.withLock { () -> Bool in
            if videoChannel === channel { videoChannel = nil }
            if audioChannel === channel { audioChannel = nil }
            return !closed && !isConnectedLocked()
        }
        if shouldReconnect {
            beginConnect()
        }
    }

    private func controlChannel() -> OMTChannel? {
        lock.withLock {
            videoChannel ?? audioChannel
        }
    }

    private func sendControl(_ xml: String) {
        checkConnection()
        do {
            try controlChannel()?.sendMetadataXML(xml)
        } catch {
            onError?(error)
        }
    }

    private func receive(_ metadata: OMTMetadata) {
        if metadata.xml.hasPrefix("<OMTInfo") {
            senderInfo = OMTSenderInfo(xml: metadata.xml)
        } else if metadata.xml.hasPrefix("<OMTRedirect") {
            let newAddress = metadata.xml.omtXMLAttribute("Address")
            if redirectAddress != newAddress {
                redirectAddress = newAddress
                beginConnect(force: true)
            }
        }
        let mediaFrame = OMTMediaFrame(type: .metadata, timestamp: metadata.timestamp, codec: .fpa1, data: Data(metadata.xml.utf8), frameMetadata: metadata.xml)
        frameContinuation.yield(mediaFrame)
        onMetadata?(metadata)
        onFrame?(mediaFrame)
    }

    private func receive(_ frame: OMTFrame) {
        do {
            let mediaFrame = try materialize(frame)
            frameContinuation.yield(mediaFrame)
            onFrame?(mediaFrame)
        } catch {
            onError?(error)
        }
    }

    private func materialize(_ frame: OMTFrame) throws -> OMTMediaFrame {
        if frame.frameType == .video {
            return try materializeVideo(frame)
        }
        if frame.frameType == .audio {
            return try materializeAudio(frame)
        }
        return OMTMediaFrame(type: .metadata, timestamp: frame.timestamp, codec: .fpa1, data: frame.payload, frameMetadata: frame.metadata)
    }

    private func materializeVideo(_ frame: OMTFrame) throws -> OMTMediaFrame {
        guard let format = frame.videoFormat else { throw OMTError.invalidFrameLength }
        var outputData = frame.payload
        var outputCodec = format.codec
        var outputWidth = format.width
        var outputHeight = format.height
        var outputStride = format.width * 2
        let compressedData = receiveFlags.contains(.includeCompressed) || receiveFlags.contains(.compressedOnly) ? frame.payload : nil

        if format.codec == .vmx1 {
            let compressedOnly = receiveFlags.contains(.compressedOnly)
            if !compressedOnly {
                let preview = format.flags.contains(.preview)
                if preview {
                    let size = omtPreviewSize(width: format.width, height: format.height, interlaced: format.flags.contains(.interlaced))
                    outputWidth = size.width
                    outputHeight = size.height
                }
                let choice = omtPreferredDecodeFormat(preferred: preferredVideoFormat, flags: format.flags, preview: preview)
                outputCodec = choice.codec
                outputStride = outputWidth * choice.bytesPerRow
                let outputLength = omtVideoPayloadLength(codec: outputCodec, width: outputWidth, height: outputHeight, stride: outputStride)
                let codec = try videoCodec(width: format.width, height: format.height, colorSpace: format.colorSpace)
                outputData = try codec.decode(choice.vmxFormat, compressed: frame.payload, stride: outputStride, outputLength: outputLength, preview: preview)
            } else {
                outputData = Data()
                outputStride = 0
            }
        }

        return OMTMediaFrame(
            type: .video,
            timestamp: frame.timestamp,
            codec: outputCodec,
            width: outputWidth,
            height: outputHeight,
            stride: outputStride,
            flags: format.flags,
            frameRateNumerator: format.frameRateNumerator,
            frameRateDenominator: format.frameRateDenominator,
            aspectRatio: format.aspectRatio,
            colorSpace: format.colorSpace,
            data: outputData,
            compressedData: compressedData,
            frameMetadata: frame.metadata
        )
    }

    private func videoCodec(width: Int32, height: Int32, colorSpace: OMTColorSpace) throws -> OMTVMXCodec {
        let key = OMTVideoCodecKey(width: width, height: height, profile: .default, colorSpace: colorSpace)
        if let videoCodec, videoCodecKey == key {
            return videoCodec
        }
        let newCodec = try OMTVMXCodec(width: width, height: height, profile: .default, colorSpace: colorSpace, symbolProvider: vmxSymbolProvider)
        videoCodec = newCodec
        videoCodecKey = key
        return newCodec
    }

    private func materializeAudio(_ frame: OMTFrame) throws -> OMTMediaFrame {
        guard let format = frame.audioFormat else { throw OMTError.invalidFrameLength }
        guard format.codec == .fpa1 else { throw OMTError.unsupportedCodec(format.codec) }
        let decoded = OMTFPA1Codec.decode(
            frame.payload,
            channels: Int(format.channels),
            samplesPerChannel: Int(format.samplesPerChannel),
            activeChannels: format.activeChannels
        )
        return OMTMediaFrame(
            type: .audio,
            timestamp: frame.timestamp,
            codec: .fpa1,
            sampleRate: format.sampleRate,
            channels: format.channels,
            samplesPerChannel: format.samplesPerChannel,
            data: decoded,
            frameMetadata: frame.metadata
        )
    }
}
