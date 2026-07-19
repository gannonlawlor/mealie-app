package com.jackabee.mealie

import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.data.store.CacheService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CacheServiceTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var cache: CacheService

    @Before
    fun setUp() {
        cache = CacheService(tempFolder.newFolder("mealie_cache"), MealieJson)
    }

    @Test
    fun `shopping lists round trip`() {
        assertNull(cache.loadShoppingLists())
        val lists = listOf(
            ShoppingList(id = "l1", name = "Groceries", listItems = listOf(ShoppingListItem(id = "i1", note = "Milk"))),
            ShoppingList(id = "l2", name = "Hardware"),
        )
        cache.saveShoppingLists(lists)
        assertEquals(lists, cache.loadShoppingLists())
    }

    @Test
    fun `shopping list detail is cached by id`() {
        val list = ShoppingList(id = "l1", name = "Groceries")
        cache.saveShoppingListDetail(list, "l1")
        assertEquals(list, cache.loadShoppingListDetail("l1"))
        assertNull(cache.loadShoppingListDetail("other"))
    }

    @Test
    fun `meal plan weeks are cached by start date`() {
        val entries = listOf(MealPlanEntry(id = 1, date = "2026-07-13", entryType = "dinner"))
        cache.saveMealPlanWeek(entries, "2026-07-13")
        assertEquals(entries, cache.loadMealPlanWeek("2026-07-13"))
        assertNull(cache.loadMealPlanWeek("2026-07-20"))
    }

    @Test
    fun `categories and tags round trip`() {
        val categories = listOf(RecipeCategory(id = "c1", name = "Dinner", slug = "dinner"))
        val tags = listOf(RecipeTag(id = "t1", name = "Fast", slug = "fast"))
        cache.saveCategories(categories)
        cache.saveTags(tags)
        assertEquals(categories, cache.loadCategories())
        assertEquals(tags, cache.loadTags())
    }

    @Test
    fun `clearAll wipes the cache`() {
        cache.saveCategories(listOf(RecipeCategory(id = "c1", name = "Dinner", slug = "dinner")))
        cache.clearAll()
        assertNull(cache.loadCategories())
        assertFalse(cache.loadShoppingLists() != null)
    }
}
