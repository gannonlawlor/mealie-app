package com.jackabee.mealie

import com.jackabee.mealie.data.store.LocalRecipeStore
import org.junit.Assert.assertEquals
import org.junit.Test

class SlugGenerationTest {

    @Test
    fun `lowercases and replaces spaces with dashes`() {
        assertEquals("chocolate-chip-cookies", LocalRecipeStore.generateSlug("Chocolate Chip Cookies"))
    }

    @Test
    fun `strips characters that are not letters digits or dashes`() {
        assertEquals("moms-12-sugar-cookies", LocalRecipeStore.generateSlug("Mom's 1/2 Sugar Cookies!"))
        assertEquals("pasta--sauce", LocalRecipeStore.generateSlug("Pasta & Sauce"))
    }

    @Test
    fun `empty result falls back to recipe`() {
        assertEquals("recipe", LocalRecipeStore.generateSlug("!!!"))
        assertEquals("recipe", LocalRecipeStore.generateSlug(""))
    }

    @Test
    fun `keeps unicode letters like swift`() {
        assertEquals("crème-brûlée", LocalRecipeStore.generateSlug("Crème Brûlée"))
    }
}
