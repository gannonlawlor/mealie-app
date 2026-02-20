import Foundation
import Observation
import OSLog
import SkipFuse

@MainActor @Observable public class ShoppingViewModel {
    public var shoppingLists: [ShoppingList] = []
    public var selectedList: ShoppingList? = nil
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var newItemNote: String = ""

    public init() {}

    public func loadShoppingLists() async {
        isLoading = true
        errorMessage = ""

        do {
            let response = try await MealieAPI.shared.getShoppingLists()
            shoppingLists = response.items
            isLoading = false
        } catch {
            errorMessage = "Failed to load shopping lists."
            logger.error("Failed to load shopping lists: \(error)")
            isLoading = false
        }
    }

    public func loadShoppingList(id: String) async {
        isLoading = true
        do {
            selectedList = try await MealieAPI.shared.getShoppingList(id: id)
            isLoading = false
        } catch {
            logger.error("Failed to load shopping list: \(error)")
            isLoading = false
        }
    }

    public func createShoppingList(name: String) async {
        do {
            let newList = try await MealieAPI.shared.createShoppingList(name: name)
            shoppingLists.append(newList)
        } catch {
            logger.error("Failed to create shopping list: \(error)")
        }
    }

    public func deleteShoppingList(id: String) async {
        do {
            try await MealieAPI.shared.deleteShoppingList(id: id)
            shoppingLists.removeAll { $0.id == id }
        } catch {
            logger.error("Failed to delete shopping list: \(error)")
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
            logger.error("Failed to add item: \(error)")
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
            logger.error("Failed to toggle item: \(error)")
        }
    }

    public func addRecipeIngredients(listId: String, recipeId: String) async {
        do {
            try await MealieAPI.shared.addRecipeToShoppingList(listId: listId, recipeId: recipeId)
            await loadShoppingList(id: listId)
        } catch {
            logger.error("Failed to add recipe ingredients: \(error)")
        }
    }
}
