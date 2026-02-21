import XCTest
import Foundation
@testable import MealieModel

@MainActor
final class MealPlanTests: XCTestCase {

    // MARK: - Helper

    private func decodeEntry(_ json: String) throws -> MealPlanEntry {
        try JSONDecoder().decode(MealPlanEntry.self, from: json.data(using: .utf8)!)
    }

    // MARK: - displayTitle

    func testDisplayTitlePrefersRecipeName() throws {
        let entry = try decodeEntry("""
        {"id": 1, "title": "Fallback Title", "recipe": {"id": "r1", "name": "Chicken Parmesan"}}
        """)
        XCTAssertEqual(entry.displayTitle, "Chicken Parmesan")
    }

    func testDisplayTitleFallsBackToTitle() throws {
        let entry = try decodeEntry("""
        {"id": 1, "title": "My Custom Title"}
        """)
        XCTAssertEqual(entry.displayTitle, "My Custom Title")
    }

    func testDisplayTitleDefaultsToMeal() throws {
        let entry = try decodeEntry("""
        {"id": 1}
        """)
        XCTAssertEqual(entry.displayTitle, "Meal")
    }

    func testDisplayTitleSkipsEmptyRecipeName() throws {
        let entry = try decodeEntry("""
        {"id": 1, "title": "Backup", "recipe": {"id": "r1", "name": ""}}
        """)
        XCTAssertEqual(entry.displayTitle, "Backup")
    }

    func testDisplayTitleSkipsEmptyTitle() throws {
        let entry = try decodeEntry("""
        {"id": 1, "title": ""}
        """)
        XCTAssertEqual(entry.displayTitle, "Meal")
    }

    // MARK: - mealType

    func testMealTypeBreakfast() throws {
        let entry = try decodeEntry("""
        {"id": 1, "entryType": "breakfast"}
        """)
        XCTAssertEqual(entry.mealType, .breakfast)
    }

    func testMealTypeLunch() throws {
        let entry = try decodeEntry("""
        {"id": 1, "entryType": "lunch"}
        """)
        XCTAssertEqual(entry.mealType, .lunch)
    }

    func testMealTypeDinner() throws {
        let entry = try decodeEntry("""
        {"id": 1, "entryType": "dinner"}
        """)
        XCTAssertEqual(entry.mealType, .dinner)
    }

    func testMealTypeSideMapsToSnack() throws {
        let entry = try decodeEntry("""
        {"id": 1, "entryType": "side"}
        """)
        XCTAssertEqual(entry.mealType, .snack)
    }

    func testMealTypeUnknownDefaultsToDinner() throws {
        let entry = try decodeEntry("""
        {"id": 1, "entryType": "brunch"}
        """)
        XCTAssertEqual(entry.mealType, .dinner)
    }

    func testMealTypeNilDefaultsToDinner() throws {
        let entry = try decodeEntry("""
        {"id": 1}
        """)
        XCTAssertEqual(entry.mealType, .dinner)
    }

    // MARK: - MealType enum

    func testMealTypeDisplayNames() {
        XCTAssertEqual(MealType.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealType.lunch.displayName, "Lunch")
        XCTAssertEqual(MealType.dinner.displayName, "Dinner")
        XCTAssertEqual(MealType.snack.displayName, "Snack")
    }

    func testMealTypeIcons() {
        XCTAssertEqual(MealType.breakfast.icon, "sunrise")
        XCTAssertEqual(MealType.lunch.icon, "sun.max")
        XCTAssertEqual(MealType.dinner.icon, "moon.stars")
        XCTAssertEqual(MealType.snack.icon, "cup.and.saucer")
    }

    func testMealTypeRawValues() {
        XCTAssertEqual(MealType.breakfast.rawValue, "breakfast")
        XCTAssertEqual(MealType.lunch.rawValue, "lunch")
        XCTAssertEqual(MealType.dinner.rawValue, "dinner")
        XCTAssertEqual(MealType.snack.rawValue, "side")
    }

    // MARK: - MealPlanViewModel date helpers

    func testDateStringFormatsCorrectly() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: "2025-03-15")!

        let result = MealPlanViewModel.dateString(date)
        XCTAssertEqual(result, "2025-03-15")
    }

    func testStartOfWeekReturnsStartOfWeek() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        // Use a known Wednesday
        let wednesday = formatter.date(from: "2025-01-15")!
        let weekStart = MealPlanViewModel.startOfWeek(for: wednesday)
        let result = MealPlanViewModel.dateString(weekStart)

        // The start of week depends on locale, but should be a consistent day
        // Verify it's before or equal to the input date
        XCTAssertTrue(weekStart <= wednesday)

        // Verify the result is a valid date string
        XCTAssertNotNil(formatter.date(from: result))

        // Verify calling startOfWeek on the result returns the same date (idempotent)
        let again = MealPlanViewModel.startOfWeek(for: weekStart)
        XCTAssertEqual(MealPlanViewModel.dateString(again), result)
    }

    func testStartOfWeekIsIdempotent() {
        let date = Date()
        let first = MealPlanViewModel.startOfWeek(for: date)
        let second = MealPlanViewModel.startOfWeek(for: first)
        XCTAssertEqual(
            MealPlanViewModel.dateString(first),
            MealPlanViewModel.dateString(second)
        )
    }
}
