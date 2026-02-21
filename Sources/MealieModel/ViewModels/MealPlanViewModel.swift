import Foundation
import Observation
import SkipFuse

private let logger = Log(category: "MealPlan")

@MainActor @Observable public class MealPlanViewModel {
    public var weekEntries: [String: [MealPlanEntry]] = [:]
    public var todayEntries: [MealPlanEntry] = []
    public var isLoading: Bool = false
    public var currentWeekStart: Date = MealPlanViewModel.startOfWeek(for: Date())
    public var errorMessage: String = ""

    public init() {}

    public static func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    public var weekDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: currentWeekStart) }
    }

    public static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public static func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    public static func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    public func loadWeek() async {
        let startDate = MealPlanViewModel.dateString(currentWeekStart)
        let endDate = MealPlanViewModel.dateString(Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart)

        // Show cached data immediately
        if weekEntries.isEmpty, let cached = CacheService.shared.loadMealPlanWeek(startDate: startDate) {
            weekEntries = groupEntries(cached)
        }

        isLoading = weekEntries.isEmpty
        errorMessage = ""

        do {
            let response = try await MealieAPI.shared.getMealPlans(startDate: startDate, endDate: endDate)
            weekEntries = groupEntries(response.items)
            CacheService.shared.saveMealPlanWeek(response.items, startDate: startDate)
            isLoading = false
        } catch {
            if weekEntries.isEmpty {
                errorMessage = "Failed to load meal plan."
            }
            logger.error("Failed to load meal plans: \(error)")
            isLoading = false
        }
    }

    private func groupEntries(_ entries: [MealPlanEntry]) -> [String: [MealPlanEntry]] {
        var grouped: [String: [MealPlanEntry]] = [:]
        for entry in entries {
            let date = entry.date ?? ""
            if grouped[date] != nil {
                grouped[date]!.append(entry)
            } else {
                grouped[date] = [entry]
            }
        }
        return grouped
    }

    public func loadToday() async {
        do {
            todayEntries = try await MealieAPI.shared.getTodayMealPlan()
        } catch {
            errorMessage = "Failed to load today's meal plan."
            logger.error("Failed to load today's meal plan: \(error)")
        }
    }

    public func previousWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
    }

    public func nextWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
    }

    public func goToThisWeek() {
        currentWeekStart = MealPlanViewModel.startOfWeek(for: Date())
    }

    public func addMealPlan(date: Date, type: MealType, recipeId: String?) async {
        let dateStr = MealPlanViewModel.dateString(date)
        let plan = CreateMealPlan(
            date: dateStr,
            entryType: type.rawValue,
            recipeId: recipeId
        )

        do {
            let _ = try await MealieAPI.shared.createMealPlan(plan)
            await loadWeek()
        } catch {
            errorMessage = "Failed to add meal plan."
            logger.error("Failed to create meal plan: \(error)")
        }
    }

    public func deleteMealPlan(id: String) async {
        do {
            try await MealieAPI.shared.deleteMealPlan(id: id)
            await loadWeek()
        } catch {
            errorMessage = "Failed to delete meal plan."
            logger.error("Failed to delete meal plan: \(error)")
        }
    }
}
