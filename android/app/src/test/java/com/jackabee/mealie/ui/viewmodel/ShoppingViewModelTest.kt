package com.jackabee.mealie.ui.viewmodel

import com.jackabee.mealie.FakeKeyValueStore
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.data.model.ShoppingListPaginatedResponse
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalGroceryStore
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

class ShoppingViewModelTest {

    @get:Rule
    val mainRule = MainDispatcherRule()

    @get:Rule
    val tmp = TemporaryFolder()

    private class Env(root: File, rule: MainDispatcherRule) {
        val kv = FakeKeyValueStore()
        val api = FakeMealieApiSource()
        val cache = CacheService(File(root, "cache"), MealieJson)
        val groceryStore = LocalGroceryStore(kv, MealieJson)
        val vm = ShoppingViewModel(api, cache, groceryStore, rule.dispatcher)
    }

    private fun env() = Env(tmp.root, mainRule)

    // MARK: Lists loading

    @Test
    fun `loadShoppingLists loads from network and caches`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getShoppingListsHandler = {
            ShoppingListPaginatedResponse(items = listOf(ShoppingList(id = "l1", name = "Groceries")))
        }

        env.vm.loadShoppingLists()

        assertEquals(listOf("Groceries"), env.vm.uiState.value.shoppingLists.map { it.name })
        assertFalse(env.vm.uiState.value.isLoading)
        assertEquals(1, env.cache.loadShoppingLists()?.size)
    }

    @Test
    fun `loadShoppingLists shows cached lists when network fails`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.cache.saveShoppingLists(listOf(ShoppingList(id = "l1", name = "Cached")))
        env.api.getShoppingListsHandler = { throw IOException("offline") }

        env.vm.loadShoppingLists()

        assertEquals(listOf("Cached"), env.vm.uiState.value.shoppingLists.map { it.name })
        // Errors only surface when nothing is cached
        assertEquals("", env.vm.uiState.value.errorMessage)
    }

    @Test
    fun `loadShoppingLists surfaces error when nothing cached`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getShoppingListsHandler = { throw IOException("offline") }

        env.vm.loadShoppingLists()

        assertEquals("Failed to load shopping lists.", env.vm.uiState.value.errorMessage)
        assertEquals("Network error: offline", env.vm.uiState.value.errorDetail)
    }

    @Test
    fun `createShoppingList appends and deleteShoppingList removes`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.createShoppingList("Weekend")
        assertEquals(1, env.vm.uiState.value.shoppingLists.size)

        val id = env.vm.uiState.value.shoppingLists.first().id!!
        env.vm.deleteShoppingList(id)
        assertTrue(env.vm.uiState.value.shoppingLists.isEmpty())
        assertEquals(listOf(id), env.api.deletedShoppingListIds)
    }

    // MARK: Items

    @Test
    fun `addItem posts note then clears it and reloads the list`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateNewItemNote("Milk")

        env.vm.addItem("l1")

        val created = env.api.createdShoppingListItems.single()
        assertEquals("l1", created.shoppingListId)
        assertEquals("Milk", created.note)
        assertEquals("", env.vm.uiState.value.newItemNote)
        assertEquals("l1", env.vm.uiState.value.selectedList?.id)
    }

    @Test
    fun `addItem with empty note does nothing`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.addItem("l1")

        assertTrue(env.api.createdShoppingListItems.isEmpty())
    }

    @Test
    fun `toggleItem flips checked and reloads the list`() = runTest(mainRule.dispatcher) {
        val env = env()
        val item = ShoppingListItem(id = "i1", shoppingListId = "l1", checked = false, note = "Eggs")

        env.vm.toggleItem(item)

        val updated = env.api.updatedShoppingListItems.single()
        assertEquals(true, updated.checked)
        assertEquals("i1", updated.id)
        assertEquals("l1", env.vm.uiState.value.selectedList?.id)
    }

    @Test
    fun `deleteItem deletes by id and reloads the list`() = runTest(mainRule.dispatcher) {
        val env = env()
        val item = ShoppingListItem(id = "i1", shoppingListId = "l1", note = "Eggs")

        env.vm.deleteItem(item)

        assertEquals(listOf("i1"), env.api.deletedShoppingListItemIds)
        assertEquals("l1", env.vm.uiState.value.selectedList?.id)
    }

    @Test
    fun `addIngredientToList returns true and increments added count`() = runTest(mainRule.dispatcher) {
        val env = env()
        val ingredient = RecipeIngredient(quantity = 2.0, note = "flour")

        val result = env.vm.addIngredientToList("l1", ingredient)

        assertTrue(result)
        assertEquals(1, env.vm.uiState.value.addedItemCount)
        val created = env.api.createdShoppingListItems.single()
        assertEquals(2.0, created.quantity!!, 0.0)
    }

    @Test
    fun `addIngredientToList returns false on failure`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.createShoppingListItemHandler = { throw httpException(500, "err") }

        val result = env.vm.addIngredientToList("l1", RecipeIngredient(note = "flour"))

        assertFalse(result)
        assertEquals(0, env.vm.uiState.value.addedItemCount)
        assertEquals("Failed to add ingredient.", env.vm.uiState.value.errorMessage)
    }

    @Test
    fun `addRecipeIngredients posts recipe and reloads list`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.addRecipeIngredients("l1", "r1")

        assertEquals(listOf("l1" to "r1"), env.api.addRecipeToListCalls)
        assertEquals("l1", env.vm.uiState.value.selectedList?.id)
    }

    // MARK: Local pending queue

    @Test
    fun `addIngredientLocally queues item and updates counts`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.addIngredientLocally("l1", RecipeIngredient(quantity = 3.0, note = "apples"))

        assertEquals(1, env.vm.uiState.value.addedItemCount)
        assertEquals(1, env.vm.pendingCount("l1"))
        val pending = env.groceryStore.pendingItems("l1").single()
        assertEquals("3 apples", pending.note)
        assertEquals(3.0, pending.quantity!!, 0.0)
    }

    @Test
    fun `syncPendingItems uploads all and clears queue on full success`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "apples"))
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "bananas"))

        env.vm.syncPendingItems("l1")

        val state = env.vm.uiState.value
        assertEquals("Uploaded 2 items", state.syncMessage)
        assertFalse(state.isSyncing)
        assertTrue(env.groceryStore.pendingItems("l1").isEmpty())
        assertEquals(0, env.vm.pendingCount("l1"))
        assertEquals(2, env.api.createdShoppingListItems.size)
        // List reloaded after sync
        assertEquals("l1", state.selectedList?.id)
    }

    @Test
    fun `syncPendingItems keeps queue and reports partial success`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "good"))
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "bad"))
        env.api.createShoppingListItemHandler = { item ->
            if (item.note == "bad") throw httpException(500, "err")
            ShoppingListItem(id = "i-${item.note}", shoppingListId = item.shoppingListId, note = item.note)
        }

        env.vm.syncPendingItems("l1")

        val state = env.vm.uiState.value
        assertEquals("Uploaded 1/2 items", state.syncMessage)
        assertFalse(state.isSyncing)
        // Queue not cleared on partial success
        assertEquals(2, env.groceryStore.pendingItems("l1").size)
        assertEquals(2, env.vm.pendingCount("l1"))
    }

    @Test
    fun `syncPendingItems does nothing when queue is empty`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.syncPendingItems("l1")

        assertEquals("", env.vm.uiState.value.syncMessage)
        assertTrue(env.api.createdShoppingListItems.isEmpty())
    }

    @Test
    fun `refreshPendingCounts reflects store contents per list`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "a"))
        env.vm.addIngredientLocally("l1", RecipeIngredient(note = "b"))
        env.vm.addIngredientLocally("l2", RecipeIngredient(note = "c"))

        env.vm.refreshPendingCounts()

        assertEquals(2, env.vm.pendingCount("l1"))
        assertEquals(1, env.vm.pendingCount("l2"))
        assertEquals(0, env.vm.pendingCount("l3"))
    }

    // MARK: List detail cache-first

    @Test
    fun `loadShoppingList shows cached detail when network fails`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.cache.saveShoppingListDetail(ShoppingList(id = "l1", name = "Cached"), "l1")
        env.api.getShoppingListHandler = { throw IOException("offline") }

        env.vm.loadShoppingList("l1")

        assertNotNull(env.vm.uiState.value.selectedList)
        assertEquals("Cached", env.vm.uiState.value.selectedList?.name)
        assertEquals("", env.vm.uiState.value.errorMessage)
    }
}
