package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.data.model.ShoppingListPaginatedResponse
import com.jackabee.mealie.ui.screens.recipes.RecipesPane
import com.jackabee.mealie.ui.screens.shopping.ShoppingPane
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Wide-layout (tablet / unfolded foldable) regression net. Runs on
 * [RobolectricDeviceQualifiers.MediumTablet] so `isWideLayout = true` panes
 * render their two-pane list + detail split.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = RobolectricDeviceQualifiers.MediumTablet)
class WideLayoutScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun recipesPane_wide_withSelectedRecipe() {
        val env = ScreenshotEnv(tmp.root)
        runBlocking { ScreenshotFixtures.allRecipes.forEach { env.localStore.saveRecipe(it) } }
        env.authViewModel.enterLocalMode()
        env.recipeViewModel.setLocalMode(true)

        composeRule.setContent {
            ScreenshotTheme {
                RecipesPane(
                    recipeViewModel = env.recipeViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                    mealPlanViewModel = env.mealPlanViewModel,
                    authViewModel = env.authViewModel,
                    isWideLayout = true,
                    onOpenRecipe = {},
                )
            }
        }

        // Select a recipe in the list pane so the detail pane renders.
        composeRule.onNodeWithText("Spaghetti Carbonara").performClick()
        composeRule.waitForIdle()

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/RecipesPane_wide_selected.png")
    }

    @Test
    fun shoppingPane_wide_withSelectedList() {
        val env = ScreenshotEnv(tmp.root)
        env.api.getShoppingListsHandler = {
            ShoppingListPaginatedResponse(
                items = listOf(ScreenshotFixtures.groceriesList(), ScreenshotFixtures.farmersMarketList()),
            )
        }
        env.api.getShoppingListHandler = { id ->
            if (id == ScreenshotFixtures.GROCERIES_LIST_ID) {
                ScreenshotFixtures.groceriesList()
            } else {
                ScreenshotFixtures.farmersMarketList()
            }
        }

        composeRule.setContent {
            ScreenshotTheme {
                ShoppingPane(
                    shoppingViewModel = env.shoppingViewModel,
                    isWideLayout = true,
                    onOpenList = {},
                )
            }
        }

        // Select a list in the list pane so the detail pane renders.
        composeRule.onNodeWithText("Groceries").performClick()
        composeRule.waitForIdle()

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/ShoppingPane_wide_selected.png")
    }
}
