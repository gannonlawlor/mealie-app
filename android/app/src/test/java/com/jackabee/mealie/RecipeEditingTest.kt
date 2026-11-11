package com.jackabee.mealie

import com.jackabee.mealie.data.model.*
import org.junit.Assert.*
import org.junit.Test

class RecipeEditingTest {
    private fun ingredient(id: String) = RecipeIngredient(quantity = 2.0,
        unit = IngredientUnit(id = "cup", name = "cup"), food = IngredientFood(id = "flour", name = "flour"),
        note = "sifted", display = "2 cups flour", isFood = true, disableAmount = false,
        referenceId = id, title = "Dough", originalText = "2 cups flour, sifted")

    @Test fun `unchanged ingredient round trips every field`() {
        val original = ingredient("flour")
        assertEquals(original, IngredientDraft(original).value())
    }

    @Test fun `deleting a duplicate text row preserves surviving metadata`() {
        val second = ingredient("second")
        val rows = mutableListOf(IngredientDraft(ingredient("first")), IngredientDraft(second))
        rows.removeAt(0)
        assertEquals(listOf(second), rows.mapNotNull { it.value() })
    }

    @Test fun `editing an ingredient keeps section and reference but does not pretend to parse quantities`() {
        val changed = IngredientDraft(ingredient("flour")).copy(text = "3 cups flour").value()!!
        assertEquals("flour", changed.referenceId)
        assertEquals("Dough", changed.title)
        assertEquals("3 cups flour", changed.displayText)
        assertNull(changed.quantity)
    }

    @Test fun `edited instruction retains id title and references`() {
        val original = RecipeInstruction(id = "step", title = "Mix", text = "Stir", ingredientReferences = listOf("flour"))
        assertEquals(original, InstructionDraft(original).value())
        assertEquals(original.copy(text = "Whisk"), InstructionDraft(original).copy(text = "Whisk").value())
    }

    @Test fun `empty section headings survive unrelated edits`() {
        val heading = RecipeInstruction(id = "section", title = "Sauce")
        assertEquals(heading, InstructionDraft(heading).value())
        assertNull(InstructionDraft().value())
    }

    @Test fun `unavailable taxonomy survives while visible deselection is respected`() {
        val hidden = RecipeTag(id = "hidden")
        val visible = RecipeTag(id = "visible")
        assertEquals(listOf(hidden), editedAssociations(listOf(hidden, visible), listOf(visible), emptySet()) { it.id })
    }
}
