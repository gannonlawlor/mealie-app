import Foundation
import Observation
import SkipFuse

@MainActor @Observable public class ShoppingViewModel {
    public var shoppingLists: [ShoppingList] = []
    public var selectedList: ShoppingList? = nil
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var newItemNote: String = ""

    public init() {}

    public func loadShoppingLists() async {
        if shoppingLists.isEmpty, let cached = CacheService.shared.loadShoppingLists() {
            shoppingLists = cached
        }

        isLoading = shoppingLists.isEmpty
        errorMessage = ""

        do {
            let response = try await MealieAPI.shared.getShoppingLists()
            shoppingLists = response.items
            CacheService.shared.saveShoppingLists(response.items)
            isLoading = false
        } catch {
            if shoppingLists.isEmpty {
                errorMessage = "Failed to load shopping lists."
            }
            print("Failed to load shopping lists: \(error)")
            isLoading = false
        }
    }

    public func loadShoppingList(id: String) async {
        if let cached = CacheService.shared.loadShoppingListDetail(id: id) {
            selectedList = cached
        }

        isLoading = selectedList == nil
        do {
            let list = try await MealieAPI.shared.getShoppingList(id: id)
            selectedList = list
            CacheService.shared.saveShoppingListDetail(list, id: id)
            isLoading = false
        } catch {
            if selectedList == nil {
                errorMessage = "Failed to load shopping list."
            }
            print("Failed to load shopping list: \(error)")
            isLoading = false
        }
    }

    public func createShoppingList(name: String) async {
        do {
            let newList = try await MealieAPI.shared.createShoppingList(name: name)
            shoppingLists.append(newList)
        } catch {
            errorMessage = "Failed to create shopping list."
            print("Failed to create shopping list: \(error)")
        }
    }

    public func deleteShoppingList(id: String) async {
        do {
            try await MealieAPI.shared.deleteShoppingList(id: id)
            shoppingLists.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to delete shopping list."
            print("Failed to delete shopping list: \(error)")
        }
    }

    public func addItem(toListId listId: String) async {
        guard !newItemNote.isEmpty else { return }

        let item = CreateShoppingListItem(
            shoppingListId: listId,
            note: newItemNote
        )

        do {
            let _ = try await MealieAPI.shared.createShoppingListItem(item)
            newItemNote = ""
            await loadShoppingList(id: listId)
        } catch {
            errorMessage = "Failed to add item."
            print("Failed to add item: \(error)")
        }
    }

    public func deleteItem(_ item: ShoppingListItem) async {
        guard let itemId = item.id else { return }
        do {
            try await MealieAPI.shared.deleteShoppingListItem(id: itemId)
            if let listId = item.shoppingListId {
                await loadShoppingList(id: listId)
            }
        } catch {
            errorMessage = "Failed to delete item."
            print("Failed to delete item: \(error)")
        }
    }

    public func toggleItem(_ item: ShoppingListItem) async {
        var updated = item
        updated.checked = !(item.checked ?? false)

        do {
            try await MealieAPI.shared.updateShoppingListItem(updated)
            if let listId = item.shoppingListId {
                await loadShoppingList(id: listId)
            }
        } catch {
            errorMessage = "Failed to update item."
            print("Failed to toggle item: \(error)")
        }
    }

    public func addRecipeIngredients(listId: String, recipeId: String) async {
        do {
            try await MealieAPI.shared.addRecipeToShoppingList(listId: listId, recipeId: recipeId)
            await loadShoppingList(id: listId)
        } catch {
            errorMessage = "Failed to add recipe ingredients."
            print("Failed to add recipe ingredients: \(error)")
        }
    }
}
