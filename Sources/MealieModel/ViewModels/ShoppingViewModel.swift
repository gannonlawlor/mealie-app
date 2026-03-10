import Foundation
import Observation
import SkipFuse

private let logger = Log(category: "Shopping")

@MainActor @Observable public class ShoppingViewModel {
    public var shoppingLists: [ShoppingList] = []
    public var selectedList: ShoppingList? = nil
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var errorDetail: String = ""
    public var newItemNote: String = ""
    public var addedItemCount: Int = 0
    public var pendingItemCounts: [String: Int] = [:]
    public var isSyncing: Bool = false
    public var syncMessage: String = ""

    public init() {}

    public func refreshPendingCounts() {
        let all = LocalGroceryStore.shared.loadAllPending()
        var counts: [String: Int] = [:]
        for (key, items) in all {
            counts[key] = items.count
        }
        pendingItemCounts = counts
    }

    public func pendingCount(forListId listId: String) -> Int {
        return pendingItemCounts[listId] ?? 0
    }

    public func addIngredientLocally(listId: String, ingredient: RecipeIngredient) {
        let item = PendingGroceryItem(
            shoppingListId: listId,
            note: ingredient.displayText,
            quantity: ingredient.quantity
        )
        LocalGroceryStore.shared.addPendingItem(item, forListId: listId)
        addedItemCount += 1
        refreshPendingCounts()
    }

    public func syncPendingItems(forListId listId: String) async {
        let pending = LocalGroceryStore.shared.pendingItems(forListId: listId)
        guard !pending.isEmpty else { return }

        isSyncing = true
        syncMessage = ""
        var successCount = 0

        for item in pending {
            let createItem = CreateShoppingListItem(
                shoppingListId: listId,
                note: item.note,
                quantity: item.quantity
            )
            do {
                let _ = try await MealieAPI.shared.createShoppingListItem(createItem)
                successCount += 1
            } catch {
                logger.error("Failed to sync pending item '\(item.note)': \(error)")
            }
        }

        if successCount == pending.count {
            LocalGroceryStore.shared.clearPendingItems(forListId: listId)
            syncMessage = "Uploaded \(successCount) items"
        } else {
            syncMessage = "Uploaded \(successCount)/\(pending.count) items"
        }

        refreshPendingCounts()
        isSyncing = false
        await loadShoppingList(id: listId)
    }

    public func loadShoppingLists() async {
        if shoppingLists.isEmpty, let cached = CacheService.shared.loadShoppingLists() {
            shoppingLists = cached
        }

        isLoading = shoppingLists.isEmpty
        errorMessage = ""
        errorDetail = ""

        do {
            let response = try await MealieAPI.shared.getShoppingLists()
            shoppingLists = response.items
            CacheService.shared.saveShoppingLists(response.items)
            isLoading = false
        } catch {
            if shoppingLists.isEmpty {
                errorMessage = "Failed to load shopping lists."
                errorDetail = AppEnvironment.errorDetail(error)
            }
            logger.error("Failed to load shopping lists: \(error)")
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
                errorDetail = AppEnvironment.errorDetail(error)
            }
            logger.error("Failed to load shopping list: \(error)")
            isLoading = false
        }
    }

    public func createShoppingList(name: String) async {
        do {
            let newList = try await MealieAPI.shared.createShoppingList(name: name)
            shoppingLists.append(newList)
        } catch {
            errorMessage = "Failed to create shopping list."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to create shopping list: \(error)")
        }
    }

    public func deleteShoppingList(id: String) async {
        do {
            try await MealieAPI.shared.deleteShoppingList(id: id)
            shoppingLists.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to delete shopping list."
            errorDetail = AppEnvironment.errorDetail(error)
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
            errorMessage = "Failed to add item."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to add item: \(error)")
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
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to delete item: \(error)")
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
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to toggle item: \(error)")
        }
    }

    public func addIngredientToList(listId: String, ingredient: RecipeIngredient) async -> Bool {
        let item = CreateShoppingListItem(
            shoppingListId: listId,
            note: ingredient.displayText,
            quantity: ingredient.quantity
        )
        do {
            let _ = try await MealieAPI.shared.createShoppingListItem(item)
            addedItemCount += 1
            return true
        } catch {
            errorMessage = "Failed to add ingredient."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to add ingredient to shopping list: \(error)")
            return false
        }
    }

    public func addRecipeIngredients(listId: String, recipeId: String) async {
        do {
            try await MealieAPI.shared.addRecipeToShoppingList(listId: listId, recipeId: recipeId)
            await loadShoppingList(id: listId)
        } catch {
            errorMessage = "Failed to add recipe ingredients."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to add recipe ingredients: \(error)")
        }
    }
}
