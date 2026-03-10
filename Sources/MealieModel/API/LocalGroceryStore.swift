import Foundation
import SkipFuse

public struct PendingGroceryItem: Codable, Sendable, Identifiable {
    public let id: String
    public let shoppingListId: String
    public let note: String
    public let quantity: Double?

    public init(shoppingListId: String, note: String, quantity: Double? = nil) {
        self.id = UUID().uuidString
        self.shoppingListId = shoppingListId
        self.note = note
        self.quantity = quantity
    }
}

public class LocalGroceryStore: @unchecked Sendable {
    public static let shared = LocalGroceryStore()

    private let storageKey = "mealie_pending_grocery_items"

    private init() {}

    public func loadAllPending() -> [String: [PendingGroceryItem]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: [PendingGroceryItem]].self, from: data)
        } catch {
            print("Failed to decode pending grocery items: \(error)")
            return [:]
        }
    }

    public func pendingItems(forListId listId: String) -> [PendingGroceryItem] {
        return loadAllPending()[listId] ?? []
    }

    public func addPendingItem(_ item: PendingGroceryItem, forListId listId: String) {
        var all = loadAllPending()
        var items = all[listId] ?? []
        items.append(item)
        all[listId] = items
        save(all)
    }

    public func removePendingItem(atIndex index: Int, forListId listId: String) {
        var all = loadAllPending()
        guard var items = all[listId], index < items.count else { return }
        items.remove(at: index)
        if items.isEmpty {
            all.removeValue(forKey: listId)
        } else {
            all[listId] = items
        }
        save(all)
    }

    public func clearPendingItems(forListId listId: String) {
        var all = loadAllPending()
        all.removeValue(forKey: listId)
        save(all)
    }

    public func totalPendingCount() -> Int {
        let all = loadAllPending()
        return all.values.reduce(0) { $0 + $1.count }
    }

    public func pendingCount(forListId listId: String) -> Int {
        return pendingItems(forListId: listId).count
    }

    private func save(_ data: [String: [PendingGroceryItem]]) {
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("Failed to encode pending grocery items: \(error)")
        }
    }
}
