import Foundation

public struct ShoppingList: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let groupId: String?
    public let householdId: String?
    public let listItems: [ShoppingListItem]?
    public let createdAt: String?
    public let updatedAt: String?

    public static func == (lhs: ShoppingList, rhs: ShoppingList) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var uncheckedCount: Int {
        listItems?.filter { $0.checked != true }.count ?? 0
    }

    public var checkedCount: Int {
        listItems?.filter { $0.checked == true }.count ?? 0
    }
}

public struct ShoppingListItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let shoppingListId: String?
    public var checked: Bool?
    public let position: Int?
    public let isFood: Bool?
    public let note: String?
    public let quantity: Double?
    public let unit: IngredientUnit?
    public let food: IngredientFood?
    public let labelId: String?
    public let extras: [String: String]?

    public static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var displayText: String {
        var parts: [String] = []
        if let q = quantity, q > 0 {
            parts.append(q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(q))
        }
        if let u = unit?.name, !u.isEmpty { parts.append(u) }
        if let f = food?.name, !f.isEmpty { parts.append(f) }
        if let n = note, !n.isEmpty { parts.append(n) }
        return parts.isEmpty ? "Item" : parts.joined(separator: " ")
    }
}

public struct CreateShoppingList: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct CreateShoppingListItem: Codable, Sendable {
    public let shoppingListId: String
    public let note: String
    public let quantity: Double?
    public let checked: Bool

    public init(shoppingListId: String, note: String, quantity: Double? = nil, checked: Bool = false) {
        self.shoppingListId = shoppingListId
        self.note = note
        self.quantity = quantity
        self.checked = checked
    }
}
