import XCTest
@testable import LibOMTSwift

final class OMTAPISurfaceTests: XCTestCase {
    func testCSharpStyleAliasesRemainAvailable() throws {
        XCTAssertEqual(OMTFrameType.None, [])
        XCTAssertEqual(OMTFrameType.Video, .video)
        XCTAssertEqual(OMTVideoFlags.HighBitDepth, .highBitDepth)
        XCTAssertEqual(OMTReceiveFlags.IncludeCompressed, .includeCompressed)
        XCTAssertEqual(OMTCodec.VMX1.rawValue, OMTCodec.vmx1.rawValue)
        XCTAssertEqual(OMTQuality.Default, .default)
        XCTAssertEqual(VMXProfile.Default, .default)
        XCTAssertEqual(VMXImageType.BGRA, .bgra)

        var frame = OMTMediaFrame(type: .video, codec: .uyvy)
        frame.FrameRate = 29.97
        XCTAssertEqual(frame.FrameRateN, 30000)
        XCTAssertEqual(frame.FrameRateD, 1001)

        var tally = OMTTally(preview: 1, program: 0)
        XCTAssertEqual(tally.Preview, 1)
        tally.Program = 1
        XCTAssertEqual(tally.description, "Preview: 1 Program: 1")
    }

    func testAddressAndXMLCompatibilityHelpers() {
        var address = OMTAddress(machineName: "Studio Mac", name: "Program", port: 6401)
        XCTAssertTrue(address.AddAddress("192.0.2.10"))
        XCTAssertEqual(address.ToString(), "Studio Mac (Program)")
        XCTAssertEqual(address.ToURL(), "omt://192.0.2.10:6401")

        let roundTripped = OMTAddress.FromXML(address.ToXML())
        XCTAssertEqual(roundTripped?.MachineName, "Studio Mac")
        XCTAssertEqual(roundTripped?.Name, "Program")
        XCTAssertEqual(roundTripped?.Port, 6401)
        XCTAssertEqual(roundTripped?.Addresses, ["192.0.2.10"])

        let senderInfo = OMTSenderInfo(productName: "PTZ", manufacturer: "Strictly", version: "1")
        XCTAssertEqual(OMTSenderInfo.FromXML(senderInfo.ToXML()), senderInfo)
        XCTAssertEqual(OMTRedirect.FromXML(OMTRedirect.ToXML("omt://host:6400")), "omt://host:6400")
    }
}
