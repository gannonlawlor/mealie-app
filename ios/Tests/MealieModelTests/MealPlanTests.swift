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

    func testCurrentWeekStartDefaultsToStartOfToday() {
        let vm = MealPlanViewModel()
        XCTAssertEqual(vm.currentWeekStart, Calendar.current.startOfDay(for: Date()))
    }

    func testWeekDatesReturnsSevenConsecutiveDays() {
        let vm = MealPlanViewModel()
        XCTAssertEqual(vm.weekDates.count, 7)
        XCTAssertEqual(vm.weekDates.first, vm.currentWeekStart)
        for (previous, next) in zip(vm.weekDates, vm.weekDates.dropFirst()) {
            let expected = Calendar.current.date(byAdding: .day, value: 1, to: previous)
            XCTAssertEqual(next, expected)
        }
    }

    func testPreviousAndNextWeekShiftBySevenDays() {
        let vm = MealPlanViewModel()
        let start = vm.currentWeekStart

        vm.nextWeek()
        XCTAssertEqual(vm.currentWeekStart, Calendar.current.date(byAdding: .day, value: 7, to: start))

        vm.previousWeek()
        XCTAssertEqual(vm.currentWeekStart, start)
    }

    func testGoToThisWeekResetsToStartOfToday() {
        let vm = MealPlanViewModel()
        vm.nextWeek()
        vm.nextWeek()
        vm.goToThisWeek()
        XCTAssertEqual(vm.currentWeekStart, Calendar.current.startOfDay(for: Date()))
    }
}
