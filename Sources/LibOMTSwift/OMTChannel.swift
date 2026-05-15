import Foundation
import Network

final class OMTChannel {
    private static let maxPendingVideoFrames = 3
    private static let maxPendingAudioFrames = 12
    private static let maxPendingMediaBytes = 32 * 1_048_576

    let connection: NWConnection
    let receiveFrameType: OMTFrameType

    var onReady: (() -> Void)?
    var onFrame: ((OMTFrame) -> Void)?
    var onMetadata: ((OMTMetadata) -> Void)?
    var onClose: ((OMTChannel) -> Void)?
    var onError: ((Error) -> Void)?

    private let queue: DispatchQueue
    private let lock = NSLock()
    private var receiveBuffer = Data()
    private var metadataState = OMTMetadataState()
    private var closed = false
    private var ready = false
    private var hasBeenReady = false
    private var pendingVideoFrames = 0
    private var pendingAudioFrames = 0
    private var pendingMediaBytes = 0
    private var stats = OMTStatistics()

    init(connection: NWConnection, receiveFrameType: OMTFrameType, queue: DispatchQueue) {
        self.connection = connection
        self.receiveFrameType = receiveFrameType
        self.queue = queue
    }

    var statistics: OMTStatistics {
        lock.withLock { stats }
    }

    var isConnected: Bool {
        lock.withLock { ready && !closed }
    }

    var didBecomeReady: Bool {
        lock.withLock { hasBeenReady }
    }

    var senderInfo: OMTSenderInfo? {
        lock.withLock { metadataState.senderInfo }
    }

    var tally: OMTTally {
        lock.withLock { metadataState.tally }
    }

    var suggestedQuality: OMTQuality {
        lock.withLock { metadataState.suggestedQuality }
    }

    var previewRequested: Bool {
        lock.withLock { metadataState.preview }
    }

    func isSubscribed(to frameType: OMTFrameType) -> Bool {
        lock.withLock { metadataState.subscriptions.contains(frameType) }
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.lock.withLock {
                    self.ready = true
                    self.hasBeenReady = true
                }
                self.onReady?()
                self.receiveLoop()
            case .waiting(let error):
                self.onError?(error)
                self.close()
            case .failed(let error):
                self.onError?(error)
                self.close()
            case .cancelled:
                self.close()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    @discardableResult
    func sendMetadataXML(_ xml: String, timestamp: Int64 = 0) throws -> Int {
        try send(OMTFrame.metadata(OMTMetadata(timestamp: timestamp, xml: xml)), respectSubscriptions: false)
    }

    @discardableResult
    func send(_ frame: OMTFrame, respectSubscriptions: Bool = true) throws -> Int {
        if respectSubscriptions, frame.frameType != .metadata, !isSubscribed(to: frame.frameType) {
            lock.withLock { stats.framesDropped += 1 }
            return 0
        }

        let encoded = try frame.encoded(preview: previewRequested)
        let shouldSend = lock.withLock {
            guard !shouldDropForBackpressureLocked(frameType: frame.frameType, byteCount: encoded.count) else {
                stats.framesDropped += 1
                return false
            }
            trackPendingSendLocked(frameType: frame.frameType, byteCount: encoded.count)
            return true
        }
        guard shouldSend else { return 0 }

        connection.send(content: encoded, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.lock.withLock {
                self.completePendingSendLocked(frameType: frame.frameType, byteCount: encoded.count)
            }
            if let error {
                self.onError?(error)
                self.close()
            } else {
                self.lock.withLock {
                    self.stats.bytesSent += Int64(encoded.count)
                    self.stats.bytesSentSinceLast += Int64(encoded.count)
                    self.stats.frames += 1
                    self.stats.framesSinceLast += 1
                }
            }
        })
        return encoded.count
    }

    private func shouldDropForBackpressureLocked(frameType: OMTFrameType, byteCount: Int) -> Bool {
        guard frameType != .metadata else { return false }
        if pendingMediaBytes + byteCount > Self.maxPendingMediaBytes {
            return true
        }
        if frameType.contains(.video), pendingVideoFrames >= Self.maxPendingVideoFrames {
            return true
        }
        if frameType.contains(.audio), pendingAudioFrames >= Self.maxPendingAudioFrames {
            return true
        }
        return false
    }

    private func trackPendingSendLocked(frameType: OMTFrameType, byteCount: Int) {
        guard frameType != .metadata else { return }
        if frameType.contains(.video) {
            pendingVideoFrames += 1
        }
        if frameType.contains(.audio) {
            pendingAudioFrames += 1
        }
        pendingMediaBytes += byteCount
    }

    private func completePendingSendLocked(frameType: OMTFrameType, byteCount: Int) {
        guard frameType != .metadata else { return }
        if frameType.contains(.video), pendingVideoFrames > 0 {
            pendingVideoFrames -= 1
        }
        if frameType.contains(.audio), pendingAudioFrames > 0 {
            pendingAudioFrames -= 1
        }
        pendingMediaBytes = max(0, pendingMediaBytes - byteCount)
    }

    func close() {
        let shouldClose = lock.withLock { () -> Bool in
            if closed { return false }
            closed = true
            ready = false
            return true
        }
        guard shouldClose else { return }
        connection.cancel()
        onClose?(self)
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let content, !content.isEmpty {
                self.lock.withLock {
                    self.stats.bytesReceived += Int64(content.count)
                    self.stats.bytesReceivedSinceLast += Int64(content.count)
                }
                self.receiveBuffer.append(content)
                self.processReceiveBuffer()
            }

            if let error {
                self.onError?(error)
                self.close()
                return
            }

            if isComplete {
                self.close()
                return
            }

            self.receiveLoop()
        }
    }

    private func processReceiveBuffer() {
        while receiveBuffer.count >= OMTFrame.headerLength {
            guard let dataLength = receiveBuffer.int32LittleEndian(at: 12).map(Int.init) else {
                return
            }
            guard dataLength >= 0 else {
                close()
                return
            }

            let totalLength = OMTFrame.headerLength + dataLength
            guard receiveBuffer.count >= totalLength else { return }

            let frameEnd = receiveBuffer.index(receiveBuffer.startIndex, offsetBy: totalLength)
            let frameData = Data(receiveBuffer[receiveBuffer.startIndex..<frameEnd])
            receiveBuffer.removeSubrange(receiveBuffer.startIndex..<frameEnd)

            do {
                let frame = try OMTFrame.decode(frameData)
                handle(frame)
            } catch {
                onError?(error)
                close()
                return
            }
        }
    }

    private func handle(_ frame: OMTFrame) {
        if frame.frameType == .metadata {
            var payload = frame.payload
            if payload.last == 0 {
                payload.removeLast()
            }
            let xml = frame.metadata ?? String(data: payload, encoding: .utf8) ?? ""
            lock.withLock {
                _ = metadataState.process(xml)
                stats.frames += 1
                stats.framesSinceLast += 1
            }
            onMetadata?(OMTMetadata(timestamp: frame.timestamp, xml: xml))
        } else {
            lock.withLock {
                stats.frames += 1
                stats.framesSinceLast += 1
            }
            onFrame?(frame)
            if let metadata = frame.metadata {
                onMetadata?(OMTMetadata(timestamp: frame.timestamp, xml: metadata))
            }
        }
    }
}

private extension Data {
    func int32LittleEndian(at byteOffset: Int) -> Int32? {
        guard byteOffset >= 0, count >= byteOffset + MemoryLayout<Int32>.size else { return nil }
        return withUnsafeBytes { rawBuffer in
            let value = rawBuffer.loadUnaligned(fromByteOffset: byteOffset, as: UInt32.self)
            return Int32(bitPattern: UInt32(littleEndian: value))
        }
    }
}

extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
