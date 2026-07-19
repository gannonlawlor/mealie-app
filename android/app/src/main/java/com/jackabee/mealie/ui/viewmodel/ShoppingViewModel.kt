package com.jackabee.mealie.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.jackabee.mealie.data.api.MealieApiSource
import com.jackabee.mealie.data.model.CreateShoppingListItem
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalGroceryStore
import com.jackabee.mealie.data.store.PendingGroceryItem
import com.jackabee.mealie.di.AppContainer
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.withContext

/** UI state for the shopping tab. Port of the Swift ShoppingViewModel's observable properties. */
data class ShoppingUiState(
    val shoppingLists: List<ShoppingList> = emptyList(),
    val selectedList: ShoppingList? = null,
    val isLoading: Boolean = false,
    val errorMessage: String = "",
    val errorDetail: String = "",
    val newItemNote: String = "",
    val addedItemCount: Int = 0,
    val pendingItemCounts: Map<String, Int> = emptyMap(),
    val isSyncing: Boolean = false,
    val syncMessage: String = "",
)

/** Port of ios/Sources/MealieModel/ViewModels/ShoppingViewModel.swift. */
class ShoppingViewModel(
    private val api: MealieApiSource,
    private val cache: CacheService,
    private val groceryStore: LocalGroceryStore,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ShoppingUiState())
    val uiState: StateFlow<ShoppingUiState> = _uiState.asStateFlow()

    fun updateNewItemNote(value: String) = _uiState.update { it.copy(newItemNote = value) }

    // MARK: Local pending queue

    fun refreshPendingCounts() {
        val counts = groceryStore.loadAllPending().mapValues { (_, items) -> items.size }
        _uiState.update { it.copy(pendingItemCounts = counts) }
    }

    fun pendingCount(listId: String): Int = _uiState.value.pendingItemCounts[listId] ?: 0

    fun addIngredientLocally(listId: String, ingredient: RecipeIngredient) {
        val item = PendingGroceryItem(
            shoppingListId = listId,
            note = ingredient.displayText,
            quantity = ingredient.quantity,
        )
        groceryStore.addPendingItem(item, listId)
        _uiState.update { it.copy(addedItemCount = it.addedItemCount + 1) }
        refreshPendingCounts()
    }

    suspend fun syncPendingItems(listId: String) {
        val pending = withContext(ioDispatcher) { groceryStore.pendingItems(listId) }
        if (pending.isEmpty()) return

        _uiState.update { it.copy(isSyncing = true, syncMessage = "") }
        var successCount = 0

        for (item in pending) {
            val createItem = CreateShoppingListItem(
                shoppingListId = listId,
                note = item.note,
                quantity = item.quantity,
            )
            try {
                withContext(ioDispatcher) { api.createShoppingListItem(createItem) }
                successCount += 1
            } catch (e: Exception) {
                println("Failed to sync pending item '${item.note}': $e")
            }
        }

        val message = if (successCount == pending.size) {
            withContext(ioDispatcher) { groceryStore.clearPendingItems(listId) }
            "Uploaded $successCount items"
        } else {
            "Uploaded $successCount/${pending.size} items"
        }

        refreshPendingCounts()
        _uiState.update { it.copy(isSyncing = false, syncMessage = message) }
        loadShoppingList(listId)
    }

    // MARK: Lists

    suspend fun loadShoppingLists() {
        if (_uiState.value.shoppingLists.isEmpty()) {
            withContext(ioDispatcher) { cache.loadShoppingLists() }?.let { cached ->
                _uiState.update { it.copy(shoppingLists = cached) }
            }
        }

        _uiState.update {
            it.copy(isLoading = it.shoppingLists.isEmpty(), errorMessage = "", errorDetail = "")
        }

        try {
            val response = withContext(ioDispatcher) { api.getShoppingLists() }
            withContext(ioDispatcher) { cache.saveShoppingLists(response.items) }
            _uiState.update { it.copy(shoppingLists = response.items, isLoading = false) }
        } catch (e: Exception) {
            println("Failed to load shopping lists: $e")
            _uiState.update {
                if (it.shoppingLists.isEmpty()) {
                    it.copy(errorMessage = "Failed to load shopping lists.", errorDetail = errorDetail(e), isLoading = false)
                } else {
                    it.copy(isLoading = false)
                }
            }
        }
    }

    suspend fun loadShoppingList(id: String) {
        withContext(ioDispatcher) { cache.loadShoppingListDetail(id) }?.let { cached ->
            _uiState.update { it.copy(selectedList = cached) }
        }

        _uiState.update { it.copy(isLoading = it.selectedList == null) }
        try {
            val list = withContext(ioDispatcher) { api.getShoppingList(id) }
            withContext(ioDispatcher) { cache.saveShoppingListDetail(list, id) }
            _uiState.update { it.copy(selectedList = list, isLoading = false) }
        } catch (e: Exception) {
            println("Failed to load shopping list: $e")
            _uiState.update {
                if (it.selectedList == null) {
                    it.copy(errorMessage = "Failed to load shopping list.", errorDetail = errorDetail(e), isLoading = false)
                } else {
                    it.copy(isLoading = false)
                }
            }
        }
    }

    suspend fun createShoppingList(name: String) {
        try {
            val newList = withContext(ioDispatcher) { api.createShoppingList(name) }
            _uiState.update { it.copy(shoppingLists = it.shoppingLists + newList) }
        } catch (e: Exception) {
            println("Failed to create shopping list: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to create shopping list.", errorDetail = errorDetail(e))
            }
        }
    }

    suspend fun deleteShoppingList(id: String) {
        try {
            withContext(ioDispatcher) { api.deleteShoppingList(id) }
            _uiState.update { state ->
                state.copy(shoppingLists = state.shoppingLists.filterNot { it.id == id })
            }
        } catch (e: Exception) {
            println("Failed to delete shopping list: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to delete shopping list.", errorDetail = errorDetail(e))
            }
        }
    }

    // MARK: Items

    suspend fun addItem(listId: String) {
        val note = _uiState.value.newItemNote
        if (note.isEmpty()) return

        val item = CreateShoppingListItem(shoppingListId = listId, note = note)

        try {
            withContext(ioDispatcher) { api.createShoppingListItem(item) }
            _uiState.update { it.copy(newItemNote = "") }
            loadShoppingList(listId)
        } catch (e: Exception) {
            println("Failed to add item: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to add item.", errorDetail = errorDetail(e))
            }
        }
    }

    suspend fun deleteItem(item: ShoppingListItem) {
        val itemId = item.id ?: return
        try {
            withContext(ioDispatcher) { api.deleteShoppingListItem(itemId) }
            item.shoppingListId?.let { loadShoppingList(it) }
        } catch (e: Exception) {
            println("Failed to delete item: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to delete item.", errorDetail = errorDetail(e))
            }
        }
    }

    suspend fun toggleItem(item: ShoppingListItem) {
        val updated = item.copy(checked = !(item.checked ?: false))

        try {
            withContext(ioDispatcher) { api.updateShoppingListItem(updated) }
            item.shoppingListId?.let { loadShoppingList(it) }
        } catch (e: Exception) {
            println("Failed to toggle item: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to update item.", errorDetail = errorDetail(e))
            }
        }
    }

    suspend fun addIngredientToList(listId: String, ingredient: RecipeIngredient): Boolean {
        val item = CreateShoppingListItem(
            shoppingListId = listId,
            note = ingredient.displayText,
            quantity = ingredient.quantity,
        )
        return try {
            withContext(ioDispatcher) { api.createShoppingListItem(item) }
            _uiState.update { it.copy(addedItemCount = it.addedItemCount + 1) }
            true
        } catch (e: Exception) {
            println("Failed to add ingredient to shopping list: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to add ingredient.", errorDetail = errorDetail(e))
            }
            false
        }
    }

    suspend fun addRecipeIngredients(listId: String, recipeId: String) {
        try {
            withContext(ioDispatcher) { api.addRecipeToShoppingList(listId, recipeId) }
            loadShoppingList(listId)
        } catch (e: Exception) {
            println("Failed to add recipe ingredients: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to add recipe ingredients.", errorDetail = errorDetail(e))
            }
        }
    }

    companion object {
        fun factory(container: AppContainer): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                ShoppingViewModel(
                    api = container.api,
                    cache = container.cache,
                    groceryStore = container.localGroceryStore,
                )
            }
        }
    }
}
