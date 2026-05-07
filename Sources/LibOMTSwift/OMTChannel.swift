import Foundation
import Network

final class OMTChannel {
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
    private var stats = OMTStatistics()

    init(connection: NWConnection, receiveFrameType: OMTFrameType, queue: DispatchQueue) {
        self.connection = connection
        self.receiveFrameType = receiveFrameType
        self.queue = queue
    }

    var statistics: OMTStatistics {
        lock.withLock { stats }
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
                self.onReady?()
                self.receiveLoop()
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

        let encoded = try frame.encoded()
        connection.send(content: encoded, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
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

    func close() {
        let shouldClose = lock.withLock { () -> Bool in
            if closed { return false }
            closed = true
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
            let dataLength = Int(Int32(littleEndianBytes: receiveBuffer[12..<16]))
            guard dataLength >= 0 else {
                close()
                return
            }

            let totalLength = OMTFrame.headerLength + dataLength
            guard receiveBuffer.count >= totalLength else { return }

            let frameData = Data(receiveBuffer.prefix(totalLength))
            receiveBuffer.removeFirst(totalLength)

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

private extension Int32 {
    init(littleEndianBytes bytes: Data.SubSequence) {
        var value: UInt32 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt32(byte) << UInt32(index * 8)
        }
        self = Int32(bitPattern: value)
    }
}

extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
