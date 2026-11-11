package com.jackabee.mealie

import com.jackabee.mealie.data.model.*
import org.junit.Assert.*
import org.junit.Test

class RecipePrintDocumentTest {
    @Test fun printUsesDisplayedContentAndEscapesMarkup() {
        val recipe = Recipe(name = "Soup & <script>bad()</script>", description = "Line one\nLine two",
            recipeYield = "4 servings", prepTime = "PT15M",
            recipeIngredient = listOf(RecipeIngredient(title = "Sauce", quantity = 2.0, unit = IngredientUnit(name = "cups"), food = IngredientFood(name = "rice"))),
            recipeInstructions = listOf(RecipeInstruction(title = "Finish", text = "Mix <gently> & serve.")),
            nutrition = Nutrition(calories = "200"), orgURL = "https://example.test/?a=1&b=2")
        val html = RecipePrintDocument.html(recipe)
        assertFalse(html.contains("<script>"))
        listOf("Soup &amp; &lt;script&gt;", "Line one\nLine two", "4 servings", "15m", "2 cups rice",
            "<h3>Sauce</h3>", "<h3>Finish</h3>", "Mix &lt;gently&gt; &amp; serve.", "200", "?a=1&amp;b=2").forEach {
            assertTrue(it, html.contains(it))
        }
    }

    @Test fun emptyRecipeOmitsMissingSections() {
        val html = RecipePrintDocument.html(Recipe())
        assertTrue(html.contains("<h1>Recipe</h1>"))
        assertFalse(html.contains("<h2>"))
        assertFalse(html.contains("null"))
    }

    @Test fun longRecipeRetainsLastInstruction() {
        val html = RecipePrintDocument.html(Recipe(name = "Long recipe", recipeInstructions =
            (1..100).map { RecipeInstruction(text = "Instruction $it: " + "Stir gently. ".repeat(20)) }))
        assertTrue(html.contains("<strong>100.</strong> Instruction 100:"))
    }
}
