import XCTest
import Foundation
@testable import MealieModel

final class RecipeIngredientTests: XCTestCase {

    func testDisplayTextPrefersDisplayField() {
        let ingredient = RecipeIngredient(
            quantity: 2.0, unit: nil, food: nil, note: nil,
            isFood: nil, disableAmount: nil, display: "2 cups flour",
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "2 cups flour")
    }

    func testDisplayTextBuildsFromParts() {
        let ingredient = RecipeIngredient(
            quantity: 2.0,
            unit: IngredientUnit(id: "u1", name: "cups", abbreviation: nil, description: nil),
            food: IngredientFood(id: "f1", name: "flour", description: nil, labelId: nil),
            note: "sifted",
            isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "2 cups flour sifted")
    }

    func testDisplayTextWholeNumberTruncatesDecimal() {
        let ingredient = RecipeIngredient(
            quantity: 3.0, unit: nil,
            food: IngredientFood(id: "f1", name: "eggs", description: nil, labelId: nil),
            note: nil, isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "3 eggs")
    }

    func testDisplayTextFractionalQuantityPreserved() {
        let ingredient = RecipeIngredient(
            quantity: 1.5,
            unit: IngredientUnit(id: "u1", name: "tsp", abbreviation: nil, description: nil),
            food: IngredientFood(id: "f1", name: "salt", description: nil, labelId: nil),
            note: nil, isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "1.5 tsp salt")
    }

    func testDisplayTextSkipsZeroQuantity() {
        let ingredient = RecipeIngredient(
            quantity: 0.0, unit: nil,
            food: IngredientFood(id: "f1", name: "salt", description: nil, labelId: nil),
            note: nil, isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "salt")
    }

    func testDisplayTextAllNilFieldsReturnsEmpty() {
        let ingredient = RecipeIngredient(
            quantity: nil, unit: nil, food: nil, note: nil,
            isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "")
    }

    func testDisplayTextNoteOnly() {
        let ingredient = RecipeIngredient(
            quantity: nil, unit: nil, food: nil, note: "a pinch of salt",
            isFood: nil, disableAmount: nil, display: nil,
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "a pinch of salt")
    }

    func testDisplayTextEmptyDisplayFallsBackToParts() {
        let ingredient = RecipeIngredient(
            quantity: 1.0, unit: nil,
            food: IngredientFood(id: "f1", name: "onion", description: nil, labelId: nil),
            note: nil, isFood: nil, disableAmount: nil, display: "",
            title: nil, originalText: nil, referenceId: nil
        )
        XCTAssertEqual(ingredient.displayText, "1 onion")
    }
}
