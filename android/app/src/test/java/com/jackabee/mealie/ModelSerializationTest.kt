package com.jackabee.mealie

import com.jackabee.mealie.data.model.AuthToken
import com.jackabee.mealie.data.model.CreateMealPlan
import com.jackabee.mealie.data.model.CreateRecipeFromURL
import com.jackabee.mealie.data.model.CreateShoppingListItem
import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealPlanPaginatedResponse
import com.jackabee.mealie.data.model.MealType
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipePaginatedResponse
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelSerializationTest {

    private val json: Json = MealieJson

    @Test
    fun `recipe decodes realistic camelCase Mealie v2 payload`() {
        val payload = """
        {
            "id": "abc-123",
            "userId": "ignored-unknown-key",
            "slug": "spaghetti-carbonara",
            "name": "Spaghetti Carbonara",
            "description": "Classic Roman pasta",
            "image": "img-id",
            "recipeCategory": [{"id": "c1", "name": "Dinner", "slug": "dinner"}],
            "tags": [{"id": "t1", "name": "Pasta", "slug": "pasta"}],
            "rating": 4,
            "recipeYield": "4 servings",
            "recipeIngredient": [
                {
                    "quantity": 200.0,
                    "unit": {"id": "u1", "name": "grams", "abbreviation": "g"},
                    "food": {"id": "f1", "name": "spaghetti"},
                    "note": "dry",
                    "isFood": true,
                    "disableAmount": false,
                    "display": "200 grams spaghetti dry",
                    "referenceId": "ref-1"
                },
                {"note": "salt to taste", "quantity": 0.0}
            ],
            "recipeInstructions": [
                {"id": "i1", "title": "", "text": "Boil pasta.", "ingredientReferences": ["ref-1"]},
                {"id": "i2", "text": "Mix eggs and cheese."}
            ],
            "totalTime": "30 minutes",
            "prepTime": "10 minutes",
            "performTime": "20 minutes",
            "nutrition": {"calories": "600", "proteinContent": "25"},
            "settings": {"public": true, "showNutrition": false, "disableAmount": true},
            "dateAdded": "2024-01-01",
            "dateUpdated": "2024-06-01T10:00:00",
            "orgURL": "https://example.com/carbonara",
            "extras": {"source": "grandma"}
        }
        """.trimIndent()

        val recipe = json.decodeFromString(Recipe.serializer(), payload)
        assertEquals("abc-123", recipe.id)
        assertEquals("spaghetti-carbonara", recipe.slug)
        assertEquals(2, recipe.recipeIngredient?.size)
        assertEquals("200 grams spaghetti dry", recipe.recipeIngredient?.get(0)?.displayText)
        assertEquals("salt to taste", recipe.recipeIngredient?.get(1)?.displayText)
        assertEquals("Boil pasta.", recipe.recipeInstructions?.get(0)?.text)
        assertEquals(listOf("ref-1"), recipe.recipeInstructions?.get(0)?.ingredientReferences)
        // "public" JSON key maps to isPublic
        assertEquals(true, recipe.settings?.isPublic)
        assertEquals(false, recipe.settings?.showNutrition)
        assertEquals("600", recipe.nutrition?.calories)
        assertEquals(mapOf("source" to "grandma"), recipe.extras)
        // missing keys stay null
        assertNull(recipe.tools)
    }

    @Test
    fun `recipe round-trips and encodes public key for settings`() {
        val payload = """{"id":"r1","name":"Test","settings":{"public":true}}"""
        val recipe = json.decodeFromString(Recipe.serializer(), payload)
        val encoded = json.encodeToString(Recipe.serializer(), recipe)
        val obj = json.parseToJsonElement(encoded).jsonObject
        assertTrue(obj["settings"]!!.jsonObject.containsKey("public"))
        assertFalse(obj["settings"]!!.jsonObject.containsKey("isPublic"))
        // null fields are omitted, mirroring Swift's encodeIfPresent
        assertFalse(obj.containsKey("slug"))
        val decodedAgain = json.decodeFromString(Recipe.serializer(), encoded)
        assertEquals(recipe, decodedAgain)
    }

    @Test
    fun `paginated response uses snake_case per_page and total_pages only`() {
        val payload = """
        {
            "page": 2,
            "per_page": 30,
            "total": 95,
            "total_pages": 4,
            "items": [
                {"id": "r1", "slug": "one", "name": "One", "rating": 5, "dateUpdated": "2024-05-01"},
                {"id": "r2", "slug": "two", "name": "Two"}
            ]
        }
        """.trimIndent()

        val response = json.decodeFromString(RecipePaginatedResponse.serializer(), payload)
        assertEquals(2, response.page)
        assertEquals(30, response.perPage)
        assertEquals(95, response.total)
        assertEquals(4, response.totalPages)
        assertEquals(2, response.items.size)
        assertEquals("one", response.items[0].slug)
    }

    @Test
    fun `auth token decodes snake_case keys`() {
        val payload = """{"access_token": "jwt-token-value", "token_type": "bearer"}"""
        val token = json.decodeFromString(AuthToken.serializer(), payload)
        assertEquals("jwt-token-value", token.accessToken)
        assertEquals("bearer", token.tokenType)
    }

    @Test
    fun `meal plan entry has Int id and helpers`() {
        val payload = """
        {
            "page": 1, "per_page": -1, "total": 2, "total_pages": 1,
            "items": [
                {
                    "id": 42,
                    "date": "2026-07-18",
                    "entryType": "breakfast",
                    "title": "",
                    "text": "",
                    "recipeId": "abc",
                    "recipe": {"id": "abc", "slug": "pancakes", "name": "Pancakes"}
                },
                {"id": 43, "date": "2026-07-18", "entryType": "side", "title": "Chips"}
            ]
        }
        """.trimIndent()

        val response = json.decodeFromString(MealPlanPaginatedResponse.serializer(), payload)
        val first = response.items[0]
        assertEquals(42, first.id)
        assertEquals("Pancakes", first.displayTitle)
        assertEquals(MealType.BREAKFAST, first.mealType)

        val second = response.items[1]
        assertEquals("Chips", second.displayTitle)
        // "side" maps to SNACK, displayed as "Snack"
        assertEquals(MealType.SNACK, second.mealType)
        assertEquals("Snack", second.mealType.displayName)

        // unknown entry type falls back to dinner; no title falls back to "Meal"
        val unknown = MealPlanEntry(id = 1, entryType = "brunch")
        assertEquals(MealType.DINNER, unknown.mealType)
        assertEquals("Meal", unknown.displayTitle)
    }

    @Test
    fun `shopping list counts and item display text`() {
        val payload = """
        {
            "id": "list-1",
            "name": "Groceries",
            "listItems": [
                {"id": "i1", "checked": false, "note": "Milk", "quantity": 1.0},
                {"id": "i2", "checked": true, "note": "Eggs", "quantity": 12.0},
                {"id": "i3", "note": "Bread"}
            ]
        }
        """.trimIndent()

        val list = json.decodeFromString(ShoppingList.serializer(), payload)
        assertEquals(2, list.uncheckedCount)
        assertEquals(1, list.checkedCount)
        assertEquals("1 Milk", list.listItems!![0].displayText)
        assertEquals("Bread", list.listItems!![2].displayText)
        assertEquals("Item", ShoppingListItem().displayText)

        // fractional quantity keeps decimals; whole quantity drops them
        val half = ShoppingListItem(quantity = 1.5, note = "cups flour")
        assertEquals("1.5 cups flour", half.displayText)
    }

    @Test
    fun `create payloads always encode required defaults`() {
        val plan = CreateMealPlan(date = "2026-07-18", entryType = "dinner")
        val planJson = json.parseToJsonElement(
            json.encodeToString(CreateMealPlan.serializer(), plan)
        ).jsonObject
        assertTrue(planJson.containsKey("title"))
        assertTrue(planJson.containsKey("text"))
        assertFalse(planJson.containsKey("recipeId")) // null omitted

        val item = CreateShoppingListItem(shoppingListId = "l1", note = "Milk")
        val itemJson = json.parseToJsonElement(
            json.encodeToString(CreateShoppingListItem.serializer(), item)
        ).jsonObject
        assertTrue(itemJson.containsKey("checked"))

        val fromUrl = CreateRecipeFromURL(url = "https://example.com")
        val urlJson = json.parseToJsonElement(
            json.encodeToString(CreateRecipeFromURL.serializer(), fromUrl)
        ).jsonObject
        assertTrue(urlJson.containsKey("includeTags"))
    }
}
