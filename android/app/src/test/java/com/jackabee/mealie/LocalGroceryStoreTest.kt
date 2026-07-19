package com.jackabee.mealie

import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.store.LocalGroceryStore
import com.jackabee.mealie.data.store.PendingGroceryItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class LocalGroceryStoreTest {

    private lateinit var store: LocalGroceryStore

    @Before
    fun setUp() {
        store = LocalGroceryStore(FakeKeyValueStore(), MealieJson)
    }

    @Test
    fun `starts empty`() {
        assertTrue(store.loadAllPending().isEmpty())
        assertEquals(0, store.totalPendingCount())
    }

    @Test
    fun `add and read pending items per list`() {
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l1", note = "Milk"), "l1")
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l1", note = "Eggs", quantity = 12.0), "l1")
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l2", note = "Soap"), "l2")

        assertEquals(2, store.pendingCount("l1"))
        assertEquals(1, store.pendingCount("l2"))
        assertEquals(3, store.totalPendingCount())
        assertEquals(listOf("Milk", "Eggs"), store.pendingItems("l1").map { it.note })
        assertEquals(12.0, store.pendingItems("l1")[1].quantity!!, 0.0)
    }

    @Test
    fun `remove by index and empty lists disappear`() {
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l1", note = "Milk"), "l1")
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l1", note = "Eggs"), "l1")
        store.removePendingItem(0, "l1")
        assertEquals(listOf("Eggs"), store.pendingItems("l1").map { it.note })
        store.removePendingItem(0, "l1")
        assertTrue(store.loadAllPending().isEmpty())
        // out-of-bounds is a no-op
        store.removePendingItem(5, "l1")
    }

    @Test
    fun `clearPendingItems clears only that list`() {
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l1", note = "Milk"), "l1")
        store.addPendingItem(PendingGroceryItem(shoppingListId = "l2", note = "Soap"), "l2")
        store.clearPendingItems("l1")
        assertEquals(0, store.pendingCount("l1"))
        assertEquals(1, store.pendingCount("l2"))
    }
}
