import XCTest
@testable import LibOMTSwift

final class OMTAddressTests: XCTestCase {
    func testURLParsing() {
        let address = OMTAddress.parseURL("omt://example.local:6400")
        XCTAssertEqual(address?.host, "example.local")
        XCTAssertEqual(address?.port, 6400)
        XCTAssertEqual(address?.url, "omt://example.local:6400")
    }

    func testFullNameParsing() {
        let address = OMTAddress.parseFullName("Studio Mac (Program)", port: 6401, host: "studio.local")
        XCTAssertEqual(address?.machineName, "Studio Mac")
        XCTAssertEqual(address?.name, "Program")
        XCTAssertEqual(address?.fullName, "Studio Mac (Program)")
        XCTAssertEqual(address?.url, "omt://studio.local:6401")
    }

    func testReverseDNSHostnameIsNotUsedAsFullBonjourInstancePrefix() {
        let hostname = "syn-2603-6011-5a00-3390-0cb2-3b32-d3fe-344f.res6.spectrum.com"
        let address = OMTAddress(machineName: hostname, name: "PROGRAM OMT", port: 6400)

        XCTAssertEqual(address.machineName, "syn-2603-6011-5a00-3390-0cb2-3b32-d3fe-344f")
        XCTAssertLessThanOrEqual(address.fullName.utf8.count, 63)
        XCTAssertFalse(address.fullName.contains(".spectrum.com"))
    }

    func testLocalHostnameSuffixIsPreserved() {
        let address = OMTAddress(machineName: "mac-mini-cde.local", name: "PROGRAM OMT", port: 6400)

        XCTAssertEqual(address.machineName, "mac-mini-cde.local")
        XCTAssertEqual(address.fullName, "mac-mini-cde.local (PROGRAM OMT)")
    }
}
