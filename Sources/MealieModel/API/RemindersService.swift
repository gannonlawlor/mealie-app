import Foundation
import SkipFuse

#if canImport(EventKit)
import EventKit

public class RemindersService: @unchecked Sendable {
    public static let shared = RemindersService()

    private let store = EKEventStore()

    private init() {}

    public func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            print("Reminders access request failed: \(error)")
            return false
        }
    }

    public func addToGroceryList(text: String) async -> Bool {
        let granted = await requestAccess()
        guard granted else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = text

        // Find the Groceries list, or fall back to default
        let calendars = store.calendars(for: .reminder)
        if let groceryList = calendars.first(where: {
            $0.title.lowercased().contains("grocer")
        }) {
            reminder.calendar = groceryList
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            print("Failed to save reminder: \(error)")
            return false
        }
    }
}
#endif
