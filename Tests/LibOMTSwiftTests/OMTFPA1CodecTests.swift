import XCTest
@testable import LibOMTSwift

final class OMTFPA1CodecTests: XCTestCase {
    func testEncodesOnlyActivePlanarChannelsAndRestoresSilence() {
        let silent = Data(repeating: 0, count: 8)
        let active = Data([1, 0, 0, 0, 2, 0, 0, 0])
        let source = silent + active + silent

        let encoded = OMTFPA1Codec.encode(source, channels: 3, samplesPerChannel: 2)
        XCTAssertEqual(encoded.activeChannels, 0b010)
        XCTAssertEqual(encoded.data, active)

        let decoded = OMTFPA1Codec.decode(encoded.data, channels: 3, samplesPerChannel: 2, activeChannels: encoded.activeChannels)
        XCTAssertEqual(decoded, source)
    }
}
