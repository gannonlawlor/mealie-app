package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.ui.screens.recipes.RecipesPane
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Swipe-to-delete on the recipes list: swiping a row left reveals a Delete
 * button (and never deletes on its own), tapping elsewhere closes it again.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class RecipeSwipeToDeleteTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    private fun setUpRecipesPane(): ScreenshotEnv {
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
                    isWideLayout = false,
                    onOpenRecipe = {},
                )
            }
        }
        return env
    }

    @Test
    fun swipingRowLeft_revealsDeleteButton() {
        val env = setUpRecipesPane()

        composeRule.onNodeWithText("Spaghetti Carbonara").performTouchInput { swipeLeft() }
        composeRule.waitForIdle()

        composeRule.onNodeWithText("Delete").assertIsDisplayed()
        // The swipe alone must not delete anything.
        assert(env.recipeViewModel.uiState.value.recipes.any { it.slug == "spaghetti-carbonara" })

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/RecipesPane_swipeToDelete.png")
    }

    @Test
    fun tappingRevealedRow_closesItInsteadOfOpeningTheRecipe() {
        setUpRecipesPane()

        composeRule.onNodeWithText("Spaghetti Carbonara").performTouchInput { swipeLeft() }
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Spaghetti Carbonara").performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithText("Delete").assertDoesNotExist()
    }
}
