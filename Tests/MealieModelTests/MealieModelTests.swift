import XCTest
import OSLog
import Foundation
@testable import MealieModel

let logger: Logger = Logger(subsystem: "MealieModel", category: "Tests")

@available(macOS 13, *)
final class MealieModelTests: XCTestCase {
    func testBasic() throws {
        logger.log("running testBasic")
        XCTAssertEqual(1 + 2, 3, "basic test")
    }
}
