import XCTest
@testable import LibOMTSwift

final class OMTFrameTests: XCTestCase {
    func testMetadataFrameRoundTripsAsPayload() throws {
        let metadata = OMTMetadata(timestamp: 42, xml: OMTMetadataCommand.subscribeVideo)
        let encoded = try OMTFrame.metadata(metadata).encoded()
        let decoded = try OMTFrame.decode(encoded)

        XCTAssertEqual(decoded.frameType, .metadata)
        XCTAssertEqual(decoded.timestamp, 42)
        XCTAssertEqual(decoded.metadata, OMTMetadataCommand.subscribeVideo)
        XCTAssertEqual(decoded.payload.last, 0)

        let headerMetadataLength = UInt16(encoded[10]) | (UInt16(encoded[11]) << 8)
        XCTAssertEqual(headerMetadataLength, 0)
    }

    func testVideoFrameRoundTripsAttachedMetadata() throws {
        let payload = Data([1, 2, 3, 4])
        let frame = OMTFrame(
            frameType: .video,
            timestamp: 100,
            videoFormat: OMTVideoFormatDescription(
                codec: .vmx1,
                width: 1920,
                height: 1080,
                frameRateNumerator: 30000,
                frameRateDenominator: 1001,
                aspectRatio: 16.0 / 9.0,
                flags: [.interlaced, .alpha],
                colorSpace: .bt709
            ),
            payload: payload,
            metadata: #"<Frame Note="ok" />"#
        )

        let decoded = try OMTFrame.decode(try frame.encoded())
        XCTAssertEqual(decoded.frameType, .video)
        XCTAssertEqual(decoded.timestamp, 100)
        XCTAssertEqual(decoded.videoFormat?.codec, .vmx1)
        XCTAssertEqual(decoded.videoFormat?.width, 1920)
        XCTAssertEqual(decoded.payload, payload)
        XCTAssertEqual(decoded.metadata, #"<Frame Note="ok" />"#)
    }
}
