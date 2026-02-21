import XCTest
import Foundation
@testable import MealieModel

final class ShoppingListTests: XCTestCase {

    // MARK: - Helper

    private func decodeShoppingList(_ json: String) throws -> ShoppingList {
        try JSONDecoder().decode(ShoppingList.self, from: json.data(using: .utf8)!)
    }

    private func decodeItem(_ json: String) throws -> ShoppingListItem {
        try JSONDecoder().decode(ShoppingListItem.self, from: json.data(using: .utf8)!)
    }

    // MARK: - uncheckedCount / checkedCount

    func testCountsWithMixedItems() throws {
        let list = try decodeShoppingList("""
        {
            "id": "list-1", "name": "Test",
            "listItems": [
                {"id": "1", "checked": false},
                {"id": "2", "checked": true},
                {"id": "3", "checked": false},
                {"id": "4", "checked": true}
            ]
        }
        """)
        XCTAssertEqual(list.uncheckedCount, 2)
        XCTAssertEqual(list.checkedCount, 2)
    }

    func testCountsWithNilListItems() throws {
        let list = try decodeShoppingList("""
        {"id": "list-1", "name": "Empty"}
        """)
        XCTAssertEqual(list.uncheckedCount, 0)
        XCTAssertEqual(list.checkedCount, 0)
    }

    func testCountsAllChecked() throws {
        let list = try decodeShoppingList("""
        {
            "id": "list-1", "name": "Done",
            "listItems": [
                {"id": "1", "checked": true},
                {"id": "2", "checked": true}
            ]
        }
        """)
        XCTAssertEqual(list.uncheckedCount, 0)
        XCTAssertEqual(list.checkedCount, 2)
    }

    func testCountsAllUnchecked() throws {
        let list = try decodeShoppingList("""
        {
            "id": "list-1", "name": "Todo",
            "listItems": [
                {"id": "1", "checked": false},
                {"id": "2", "checked": false}
            ]
        }
        """)
        XCTAssertEqual(list.uncheckedCount, 2)
        XCTAssertEqual(list.checkedCount, 0)
    }

    func testCountsWithNilCheckedTreatedAsUnchecked() throws {
        let list = try decodeShoppingList("""
        {
            "id": "list-1", "name": "Nil check",
            "listItems": [
                {"id": "1"},
                {"id": "2", "checked": true}
            ]
        }
        """)
        XCTAssertEqual(list.uncheckedCount, 1)
        XCTAssertEqual(list.checkedCount, 1)
    }

    // MARK: - ShoppingListItem.displayText

    func testItemDisplayTextWithAllParts() throws {
        let item = try decodeItem("""
        {
            "id": "1",
            "quantity": 2.0,
            "unit": {"id": "u1", "name": "lbs"},
            "food": {"id": "f1", "name": "chicken"},
            "note": "boneless"
        }
        """)
        XCTAssertEqual(item.displayText, "2 lbs chicken boneless")
    }

    func testItemDisplayTextAllNilReturnsItem() throws {
        let item = try decodeItem("""
        {"id": "1"}
        """)
        XCTAssertEqual(item.displayText, "Item")
    }

    func testItemDisplayTextWholeNumberTruncation() throws {
        let item = try decodeItem("""
        {
            "id": "1",
            "quantity": 5.0,
            "food": {"id": "f1", "name": "apples"}
        }
        """)
        XCTAssertEqual(item.displayText, "5 apples")
    }

    func testItemDisplayTextFractionalQuantity() throws {
        let item = try decodeItem("""
        {
            "id": "1",
            "quantity": 0.5,
            "unit": {"id": "u1", "name": "cup"},
            "food": {"id": "f1", "name": "sugar"}
        }
        """)
        XCTAssertEqual(item.displayText, "0.5 cup sugar")
    }

    func testItemDisplayTextNoteOnly() throws {
        let item = try decodeItem("""
        {"id": "1", "note": "check the pantry"}
        """)
        XCTAssertEqual(item.displayText, "check the pantry")
    }
}
