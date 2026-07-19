package com.jackabee.mealie

import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.store.OfflineRecipeStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class OfflineRecipeStoreTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var store: OfflineRecipeStore

    @Before
    fun setUp() {
        store = OfflineRecipeStore(tempFolder.newFolder("files"), FakeKeyValueStore(), MealieJson)
    }

    @Test
    fun `save load and remove recipe with image`() {
        val recipe = Recipe(id = "r1", slug = "cake", name = "Cake")
        store.saveRecipe(recipe, imageData = byteArrayOf(1, 2, 3))

        assertTrue(store.isRecipeSavedOffline("r1"))
        assertEquals(recipe, store.loadRecipe("r1"))
        assertEquals(recipe, store.loadRecipeBySlug("cake"))
        val imagePath = store.imageFilePath("r1")
        assertNotNull(imagePath)
        assertEquals(3, File(imagePath!!).length().toInt())

        store.removeRecipe("r1")
        assertFalse(store.isRecipeSavedOffline("r1"))
        assertNull(store.loadRecipe("r1"))
        assertNull(store.imageFilePath("r1"))
    }

    @Test
    fun `recipe without id is ignored`() {
        store.saveRecipe(Recipe(name = "No Id"), imageData = null)
        assertTrue(store.savedRecipeIds().isEmpty())
    }

    @Test
    fun `loadAllSavedRecipes and clearAll`() {
        store.saveRecipe(Recipe(id = "a", slug = "a", name = "A"), null)
        store.saveRecipe(Recipe(id = "b", slug = "b", name = "B"), null)
        assertEquals(setOf("A", "B"), store.loadAllSavedRecipes().mapNotNull { it.name }.toSet())

        store.clearAll()
        assertTrue(store.loadAllSavedRecipes().isEmpty())
        assertTrue(store.savedRecipeIds().isEmpty())
    }
}
