import Network
import XCTest
@testable import LibOMTSwift

final class OMTLoopbackTests: XCTestCase {
    func testExternalVideoReceiveWhenURLProvided() throws {
        guard let url = ProcessInfo.processInfo.environment["OMT_TEST_URL"], !url.isEmpty else {
            throw XCTSkip("Set OMT_TEST_URL to run against an external OMT source.")
        }

        let receivedFrame = expectation(description: "received external video frame")
        var receivedVideoFrame: OMTMediaFrame?
        var receivedError: Error?
        let receiver = try OMTReceiver(
            url,
            frameTypes: [.video, .metadata],
            format: .uyvyOrUYVA,
            flags: []
        )
        defer { receiver.close() }
        receiver.onFrame = { frame in
            guard frame.type == .video else { return }
            receivedVideoFrame = frame
            receivedFrame.fulfill()
        }
        receiver.onError = { error in
            receivedError = error
        }

        wait(for: [receivedFrame], timeout: 5)
        let videoStats = receiver.getVideoStatistics()
        let senderInfo = receiver.getSenderInformation()
        XCTAssertNil(receivedError)
        XCTAssertEqual(
            receivedVideoFrame?.type,
            .video,
            "connected=\(receiver.isConnected), bytes=\(videoStats.bytesReceived), frames=\(videoStats.frames), senderInfo=\(String(describing: senderInfo))"
        )
        XCTAssertGreaterThan(Int(receivedVideoFrame?.width ?? 0), 0)
        XCTAssertGreaterThan(Int(receivedVideoFrame?.height ?? 0), 0)
        XCTAssertFalse(receivedVideoFrame?.data.isEmpty ?? true)
    }

    func testExternalPreviewVideoReceiveWhenURLProvided() throws {
        guard let url = ProcessInfo.processInfo.environment["OMT_TEST_URL"], !url.isEmpty else {
            throw XCTSkip("Set OMT_TEST_URL to run against an external OMT source.")
        }

        let receivedFrame = expectation(description: "received external preview video frame")
        var receivedVideoFrame: OMTMediaFrame?
        var receivedError: Error?
        let receiver = try OMTReceiver(
            url,
            frameTypes: [.video, .metadata],
            format: .uyvyOrUYVA,
            flags: [.preview]
        )
        defer { receiver.close() }
        receiver.onFrame = { frame in
            guard frame.type == .video else { return }
            receivedVideoFrame = frame
            receivedFrame.fulfill()
        }
        receiver.onError = { error in
            receivedError = error
        }

        wait(for: [receivedFrame], timeout: 5)
        XCTAssertNil(receivedError)
        let frame = try XCTUnwrap(receivedVideoFrame)
        XCTAssertTrue(frame.flags.contains(.preview))
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
        XCTAssertEqual(frame.data.count, Int(frame.stride * frame.height))
        if frame.aspectRatio > 1 {
            XCTAssertGreaterThan(
                frame.width,
                frame.height,
                "Preview dimensions should track the display aspect ratio; got \(frame.width)x\(frame.height) for aspect \(frame.aspectRatio)"
            )
        }
    }

    func testSenderReceiverVideoLoopback() throws {
        let sender = try OMTSender(
            name: "Loopback",
            portRange: 6550...6560
        )
        defer { sender.stop() }

        let receivedFrame = expectation(description: "received video frame")
        var receivedVideoFrame: OMTMediaFrame?
        var receivedError: Error?
        let receiver = try OMTReceiver(
            sender.url,
            frameTypes: [.video, .metadata],
            format: .uyvy,
            flags: []
        )
        defer { receiver.close() }
        receiver.onFrame = { frame in
            guard frame.type == .video else { return }
            receivedVideoFrame = frame
            receivedFrame.fulfill()
        }
        receiver.onError = { error in
            receivedError = error
        }

        let width = 16
        let height = 16
        let frame = OMTMediaFrame(
            type: .video,
            timestamp: 1,
            codec: .uyvy,
            width: Int32(width),
            height: Int32(height),
            stride: Int32(width * 2),
            frameRateNumerator: 30000,
            frameRateDenominator: 1001,
            aspectRatio: Float(width) / Float(height),
            colorSpace: .bt709,
            data: Data(repeating: 128, count: width * height * 2)
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline, receivedVideoFrame == nil {
                _ = try? sender.send(frame)
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        wait(for: [receivedFrame], timeout: 5)
        XCTAssertEqual(
            receivedVideoFrame?.type,
            .video,
            "senderConnections=\(sender.connectionCount), receiverConnected=\(receiver.isConnected), receiverError=\(String(describing: receivedError))"
        )
        XCTAssertEqual(receivedVideoFrame?.width, Int32(width))
        XCTAssertEqual(receivedVideoFrame?.height, Int32(height))
        XCTAssertEqual(receivedVideoFrame?.codec, .uyvy)
        XCTAssertEqual(receivedVideoFrame?.data.count, width * height * 2)
    }

    func testSenderSkipsPortThatFailsAfterListenerStart() throws {
        let occupiedPort = 6570
        let occupiedListener = try NWListener(using: omtTCPParameters(), on: NWEndpoint.Port(omtPort: occupiedPort))
        let ready = expectation(description: "occupied listener ready")
        var listenerError: Error?

        occupiedListener.newConnectionHandler = { connection in
            connection.cancel()
        }
        occupiedListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.fulfill()
            case .failed(let error):
                listenerError = error
                ready.fulfill()
            default:
                break
            }
        }
        occupiedListener.start(queue: DispatchQueue(label: "dev.strictlytyped.omtswift.tests.occupied-port"))
        wait(for: [ready], timeout: 2)

        if let listenerError {
            occupiedListener.cancel()
            throw XCTSkip("OMT loopback port \(occupiedPort) unavailable: \(listenerError)")
        }
        defer { occupiedListener.cancel() }

        let portRange = occupiedPort...(occupiedPort + 5)
        let sender = try OMTSender(
            name: "OccupiedPortLoopback",
            portRange: portRange
        )
        defer { sender.stop() }

        XCTAssertNotEqual(sender.port, occupiedPort)
        XCTAssertTrue(portRange.contains(sender.port))
    }

    func testReceiverCheckConnectionReconnectsAfterInitialFailure() throws {
        let port = 6599
        let receiver = try OMTReceiver(
            "omt://127.0.0.1:\(port)",
            frameTypes: [.video, .metadata],
            format: .uyvy,
            flags: []
        )
        defer { receiver.close() }

        let sender: OMTSender
        do {
            sender = try OMTSender(
                name: "DelayedLoopback",
                portRange: port...port
            )
        } catch {
            throw XCTSkip("OMT loopback port \(port) unavailable: \(error)")
        }
        defer { sender.stop() }

        let receivedFrame = expectation(description: "received video frame after reconnect")
        var receivedVideoFrame: OMTMediaFrame?
        receiver.onFrame = { frame in
            guard frame.type == .video else { return }
            receivedVideoFrame = frame
            receivedFrame.fulfill()
        }

        let width = 16
        let height = 16
        let frame = OMTMediaFrame(
            type: .video,
            timestamp: 1,
            codec: .uyvy,
            width: Int32(width),
            height: Int32(height),
            stride: Int32(width * 2),
            frameRateNumerator: 30000,
            frameRateDenominator: 1001,
            aspectRatio: Float(width) / Float(height),
            colorSpace: .bt709,
            data: Data(repeating: 128, count: width * height * 2)
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(4)
            while Date() < deadline, receivedVideoFrame == nil {
                receiver.checkConnection()
                _ = try? sender.send(frame)
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        wait(for: [receivedFrame], timeout: 5)
        XCTAssertEqual(receivedVideoFrame?.type, .video)
        XCTAssertEqual(receivedVideoFrame?.width, Int32(width))
        XCTAssertEqual(receivedVideoFrame?.height, Int32(height))
        XCTAssertEqual(receivedVideoFrame?.codec, .uyvy)
        XCTAssertEqual(receivedVideoFrame?.data.count, width * height * 2)
    }
}
