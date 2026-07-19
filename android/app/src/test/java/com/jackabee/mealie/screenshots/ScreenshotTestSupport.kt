package com.jackabee.mealie.screenshots

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.test.core.app.ApplicationProvider
import com.jackabee.mealie.FakeKeyValueStore
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.api.MealieClient
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.Nutrition
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.RecipeInstruction
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.data.settings.ThemePreference
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalRecipeStore
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import com.jackabee.mealie.di.AppContainer
import com.jackabee.mealie.ui.theme.MealieTheme
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.FakeLocalRecipeDao
import com.jackabee.mealie.ui.viewmodel.FakeMealieApiSource
import com.jackabee.mealie.ui.viewmodel.FakeRecipeParser
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.Dispatchers
import java.io.File
import java.time.LocalDate

/** Where golden PNGs live, relative to the app module directory (test working dir). */
const val SNAPSHOT_DIR = "src/test/roborazzi"

/** The app's real DI container as constructed by [MealieApplication] under Robolectric. */
fun appContainer(): AppContainer =
    ApplicationProvider.getApplicationContext<MealieApplication>().container

/**
 * Deterministic light/dark theme wrapper. Forces an explicit color scheme
 * (never the device/system one) and paints a background so captures are
 * never transparent.
 */
@Composable
fun ScreenshotTheme(dark: Boolean = false, content: @Composable () -> Unit) {
    MealieTheme(themePreference = if (dark) ThemePreference.DARK else ThemePreference.LIGHT) {
        Surface(modifier = Modifier.fillMaxSize()) {
            content()
        }
    }
}

/**
 * Fake-backed dependency set mirroring the Env classes in the ViewModel unit
 * tests. Everything the ViewModels touch is either an in-memory fake or a
 * real store rooted in [root] (a per-test temp folder), so no network or
 * device state is involved. All ViewModels use [Dispatchers.Unconfined] as
 * their io dispatcher so the fake-backed suspend loads complete synchronously
 * inside composition effects — no waiting, no flakiness.
 */
class ScreenshotEnv(root: File) {
    val kv = FakeKeyValueStore()
    val api = FakeMealieApiSource()
    val authStore = AuthStore(kv, MealieJson, api)
    val cache = CacheService(File(root, "cache"), MealieJson)
    val offlineStore = OfflineRecipeStore(File(root, "files"), kv, MealieJson)
    val syncService = RecipeSyncService(File(root, "files"), kv, MealieApi(MealieClient(), MealieJson), MealieJson)
    val localStore = LocalRecipeStore(FakeLocalRecipeDao(), kv, MealieJson, File(root, "local"))
    val parser = FakeRecipeParser()

    private val io = Dispatchers.Unconfined

    val authViewModel by lazy {
        AuthViewModel(authStore, api, cache, offlineStore, syncService, io)
    }

    val recipeViewModel by lazy {
        RecipeViewModel(api, localStore, syncService, offlineStore, cache, parser, io)
    }

    /** Week pinned to [ScreenshotFixtures.weekStart] so captures never depend on the run date. */
    val mealPlanViewModel by lazy {
        MealPlanViewModel(api, cache, io, today = { ScreenshotFixtures.weekStart })
    }

    /**
     * Uses the app container's [com.jackabee.mealie.data.store.LocalGroceryStore]
     * because the shopping screens read pending items from the container directly.
     */
    val shoppingViewModel by lazy {
        ShoppingViewModel(api, cache, appContainer().localGroceryStore, io)
    }
}

/**
 * Fixed fixture data. Rules: hardcoded ids/strings only, no random values,
 * no Clock/LocalDate.now(), and a meal-plan week pinned to a past date so
 * the real "today" can never fall inside it.
 */
object ScreenshotFixtures {

    /** Monday, March 10 2025 — always in the past, so no day is ever highlighted as today. */
    val weekStart: LocalDate = LocalDate.of(2025, 3, 10)

    val categoryDinner = RecipeCategory(id = "cat-dinner", name = "Dinner", slug = "dinner")
    val categoryBreakfast = RecipeCategory(id = "cat-breakfast", name = "Breakfast", slug = "breakfast")
    val tagPasta = RecipeTag(id = "tag-pasta", name = "Pasta", slug = "pasta")
    val tagItalian = RecipeTag(id = "tag-italian", name = "Italian", slug = "italian")
    val tagQuick = RecipeTag(id = "tag-quick", name = "Quick", slug = "quick")

    /** Rich recipe: sectioned ingredients, instructions with a titled step, nutrition, times. */
    val carbonara = Recipe(
        id = "recipe-carbonara",
        slug = "spaghetti-carbonara",
        name = "Spaghetti Carbonara",
        description = "A classic Roman pasta made with eggs, Pecorino Romano, guanciale and " +
            "plenty of black pepper. Silky, savory and ready in about half an hour — no cream needed.",
        recipeYield = "4 servings",
        prepTime = "PT15M",
        performTime = "PT20M",
        totalTime = "PT35M",
        rating = 5,
        recipeCategory = listOf(categoryDinner),
        tags = listOf(tagPasta, tagItalian),
        recipeIngredient = listOf(
            RecipeIngredient(title = "Pasta", display = "400 g spaghetti"),
            RecipeIngredient(display = "150 g guanciale, diced"),
            RecipeIngredient(title = "Sauce", display = "4 large egg yolks"),
            RecipeIngredient(display = "100 g Pecorino Romano, finely grated"),
            RecipeIngredient(display = "Freshly ground black pepper"),
        ),
        recipeInstructions = listOf(
            RecipeInstruction(
                text = "Bring a large pot of salted water to the boil and cook the spaghetti until al dente.",
            ),
            RecipeInstruction(
                text = "Meanwhile, render the guanciale in a cold pan over medium heat until golden and crisp.",
            ),
            RecipeInstruction(
                title = "Finish",
                text = "Off the heat, toss the pasta with the yolk and Pecorino mixture, loosening with " +
                    "pasta water until glossy. Season generously with black pepper.",
            ),
        ),
        nutrition = Nutrition(
            calories = "640",
            fatContent = "28 g",
            proteinContent = "26 g",
            carbohydrateContent = "72 g",
            fiberContent = "3 g",
            sugarContent = "2 g",
        ),
        orgURL = "https://example.com/recipes/spaghetti-carbonara",
    )

    val oats = Recipe(
        id = "recipe-oats",
        slug = "overnight-oats",
        name = "Overnight Oats",
        description = "Creamy make-ahead oats with chia, maple syrup and berries.",
        recipeYield = "2 jars",
        totalTime = "PT8H",
        recipeCategory = listOf(categoryBreakfast),
        tags = listOf(tagQuick),
        recipeIngredient = listOf(
            RecipeIngredient(display = "100 g rolled oats"),
            RecipeIngredient(display = "250 ml milk"),
            RecipeIngredient(display = "1 tbsp chia seeds"),
        ),
        recipeInstructions = listOf(
            RecipeInstruction(text = "Stir everything together and refrigerate overnight."),
        ),
    )

    val stirFry = Recipe(
        id = "recipe-stirfry",
        slug = "weeknight-stir-fry",
        name = "Weeknight Stir-Fry",
        description = "Crisp vegetables and chicken in a garlicky soy glaze, done in 20 minutes.",
        recipeYield = "3 servings",
        totalTime = "PT20M",
        recipeCategory = listOf(categoryDinner),
        tags = listOf(tagQuick),
        recipeIngredient = listOf(
            RecipeIngredient(display = "2 chicken breasts, sliced"),
            RecipeIngredient(display = "1 head broccoli, cut into florets"),
            RecipeIngredient(display = "3 tbsp soy sauce"),
        ),
        recipeInstructions = listOf(
            RecipeInstruction(text = "Stir-fry the chicken, add vegetables, then glaze with the sauce."),
        ),
    )

    val allRecipes = listOf(carbonara, oats, stirFry)

    private fun Recipe.summary() = RecipeSummary(
        id = id,
        slug = slug,
        name = name,
        description = description,
        recipeCategory = recipeCategory,
        tags = tags,
        rating = rating,
    )

    /** Meal plan entries spread across the pinned week (Mon Mar 10 – Sun Mar 16, 2025). */
    fun weekEntries(): List<MealPlanEntry> = listOf(
        MealPlanEntry(id = 1, date = "2025-03-10", entryType = "breakfast", recipe = oats.summary()),
        MealPlanEntry(id = 2, date = "2025-03-10", entryType = "dinner", recipe = carbonara.summary()),
        MealPlanEntry(id = 3, date = "2025-03-11", entryType = "lunch", title = "Leftovers"),
        MealPlanEntry(id = 4, date = "2025-03-12", entryType = "dinner", recipe = stirFry.summary()),
        MealPlanEntry(id = 5, date = "2025-03-14", entryType = "side", title = "Fruit & yogurt"),
        MealPlanEntry(id = 6, date = "2025-03-15", entryType = "dinner", recipe = carbonara.summary()),
    )

    const val GROCERIES_LIST_ID = "list-groceries"

    /** Shopping list detail with unchecked ("To Buy") and checked ("Completed") items. */
    fun groceriesList(): ShoppingList = ShoppingList(
        id = GROCERIES_LIST_ID,
        name = "Groceries",
        listItems = listOf(
            ShoppingListItem(id = "item-1", shoppingListId = GROCERIES_LIST_ID, checked = false, note = "Chicken thighs", quantity = 2.0),
            ShoppingListItem(id = "item-2", shoppingListId = GROCERIES_LIST_ID, checked = false, note = "Broccoli"),
            ShoppingListItem(id = "item-3", shoppingListId = GROCERIES_LIST_ID, checked = false, note = "Soy sauce"),
            ShoppingListItem(id = "item-4", shoppingListId = GROCERIES_LIST_ID, checked = true, note = "Rolled oats"),
            ShoppingListItem(id = "item-5", shoppingListId = GROCERIES_LIST_ID, checked = true, note = "Maple syrup"),
        ),
    )

    /** A second, simpler list so the lists pane shows more than one row. */
    fun farmersMarketList(): ShoppingList = ShoppingList(
        id = "list-market",
        name = "Farmers Market",
        listItems = listOf(
            ShoppingListItem(id = "item-6", shoppingListId = "list-market", checked = false, note = "Heirloom tomatoes"),
            ShoppingListItem(id = "item-7", shoppingListId = "list-market", checked = false, note = "Basil"),
        ),
    )
}
