import XCTest
@testable import LibOMTSwift

final class OMTAPISurfaceTests: XCTestCase {
    func testFrameRateAndTallyHelpers() throws {
        var frame = OMTMediaFrame(type: .video, codec: .uyvy)
        frame.frameRate = 29.97
        XCTAssertEqual(frame.frameRateNumerator, 30000)
        XCTAssertEqual(frame.frameRateDenominator, 1001)

        var tally = OMTTally(preview: 1, program: 0)
        XCTAssertTrue(tally.preview)
        tally.program = true
        XCTAssertEqual(tally.description, "Preview: 1 Program: 1")
    }

    func testAddressAndXMLHelpers() {
        var address = OMTAddress(machineName: "Studio Mac", name: "Program", port: 6401)
        XCTAssertTrue(address.addAddress("192.0.2.10"))
        XCTAssertEqual(address.fullName, "Studio Mac (Program)")
        XCTAssertEqual(address.url, "omt://192.0.2.10:6401")

        let roundTripped = OMTAddress(xml: address.xml)
        XCTAssertEqual(roundTripped?.machineName, "Studio Mac")
        XCTAssertEqual(roundTripped?.name, "Program")
        XCTAssertEqual(roundTripped?.port, 6401)
        XCTAssertEqual(roundTripped?.addresses, ["192.0.2.10"])

        let senderInfo = OMTSenderInfo(productName: "PTZ", manufacturer: "Strictly", version: "1")
        XCTAssertEqual(OMTSenderInfo(xml: senderInfo.xml), senderInfo)
        XCTAssertEqual(OMTRedirect.fromXML(OMTRedirect.toXML("omt://host:6400")), "omt://host:6400")
    }
}
