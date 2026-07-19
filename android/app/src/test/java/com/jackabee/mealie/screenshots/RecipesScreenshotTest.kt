package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.ui.screens.recipes.RecipeDetailScreen
import com.jackabee.mealie.ui.screens.recipes.RecipesPane
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class RecipesScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    /**
     * Local mode is used for recipe fixtures: recipes come from the in-memory
     * local store and thumbnails deterministically resolve to the placeholder
     * icon (no image files, no network).
     */
    private fun localModeEnv(): ScreenshotEnv {
        val env = ScreenshotEnv(tmp.root)
        runBlocking { ScreenshotFixtures.allRecipes.forEach { env.localStore.saveRecipe(it) } }
        env.authViewModel.enterLocalMode()
        env.recipeViewModel.setLocalMode(true)
        return env
    }

    @Test
    fun recipesPane_compact() {
        val env = localModeEnv()

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

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/RecipesPane_compact.png")
    }

    @Test
    fun recipeDetail_light() {
        val env = localModeEnv()

        composeRule.setContent {
            ScreenshotTheme {
                RecipeDetailScreen(
                    slug = "spaghetti-carbonara",
                    recipeViewModel = env.recipeViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                    mealPlanViewModel = env.mealPlanViewModel,
                    onBack = {},
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/RecipeDetail_light.png")
    }

    @Test
    fun recipeDetail_dark() {
        val env = localModeEnv()

        composeRule.setContent {
            ScreenshotTheme(dark = true) {
                RecipeDetailScreen(
                    slug = "spaghetti-carbonara",
                    recipeViewModel = env.recipeViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                    mealPlanViewModel = env.mealPlanViewModel,
                    onBack = {},
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/RecipeDetail_dark.png")
    }
}
