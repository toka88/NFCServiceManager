import XCTest
@testable import NFCServiceManager

final class NFCServiceManagerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(NFCServiceManager().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
