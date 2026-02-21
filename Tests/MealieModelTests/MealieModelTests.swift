import XCTest
import Foundation
@testable import MealieModel

final class MealieModelTests: XCTestCase {
    func testModuleImports() {
        // Sanity check that MealieModel module is importable and types are accessible
        XCTAssertNotNil(AuthToken.self)
        XCTAssertNotNil(Recipe.self)
        XCTAssertNotNil(MealPlanEntry.self)
        XCTAssertNotNil(ShoppingList.self)
    }
}
