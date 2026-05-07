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
}
