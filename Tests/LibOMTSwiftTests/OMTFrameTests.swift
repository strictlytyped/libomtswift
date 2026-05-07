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
        XCTAssertEqual(decoded.payload, Data(OMTMetadataCommand.subscribeVideo.utf8))

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

    func testPreviewPayloadDoesNotForcePreviewEncoding() throws {
        let payload = Data(0..<64)
        let frame = OMTFrame(
            frameType: .video,
            timestamp: 101,
            videoFormat: OMTVideoFormatDescription(
                codec: .vmx1,
                width: 1920,
                height: 1080,
                frameRateNumerator: 60000,
                frameRateDenominator: 1001,
                aspectRatio: 16.0 / 9.0,
                flags: [],
                colorSpace: .bt709
            ),
            payload: payload,
            previewPayloadLength: 16
        )

        let fullFrame = try OMTFrame.decode(try frame.encoded())
        XCTAssertEqual(fullFrame.videoFormat?.width, 1920)
        XCTAssertEqual(fullFrame.videoFormat?.height, 1080)
        XCTAssertEqual(fullFrame.videoFormat?.flags.contains(.preview), false)
        XCTAssertEqual(fullFrame.payload, payload)

        let previewFrame = try OMTFrame.decode(try frame.encoded(preview: true))
        XCTAssertEqual(previewFrame.videoFormat?.width, 1920)
        XCTAssertEqual(previewFrame.videoFormat?.height, 1080)
        XCTAssertEqual(previewFrame.videoFormat?.flags.contains(.preview), true)
        XCTAssertEqual(previewFrame.payload, payload.prefix(16))
    }

    func testPreviewSizeMatchesVMXPreviewDecodeSize() {
        let progressiveSize = omtPreviewSize(width: 1920, height: 1080, interlaced: false)
        XCTAssertEqual(progressiveSize.width, 240)
        XCTAssertEqual(progressiveSize.height, 135)

        let interlacedSize = omtPreviewSize(width: 1920, height: 1080, interlaced: true)
        XCTAssertEqual(interlacedSize.width, 240)
        XCTAssertEqual(interlacedSize.height, 134)

        let oddWidthSize = omtPreviewSize(width: 1928, height: 1080, interlaced: false)
        XCTAssertEqual(oddWidthSize.width, 242)
        XCTAssertEqual(oddWidthSize.height, 135)
    }
}
