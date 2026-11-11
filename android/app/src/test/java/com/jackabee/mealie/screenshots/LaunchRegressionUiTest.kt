package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.ui.screens.recipes.RecipesPane
import com.jackabee.mealie.ui.screens.recipes.components.EditRecipeDialog
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
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
class LaunchRegressionUiTest {
    @get:Rule val compose = createComposeRule()
    @get:Rule val tmp = TemporaryFolder()

    @Test fun saveWithoutIngredientEditsPreservesStructuredRecipeAndUnavailableTaxonomy() {
        val env = ScreenshotEnv(tmp.root)
        val original = ScreenshotFixtures.carbonara
        env.recipeViewModel.setLocalMode(true)
        runBlocking {
            env.localStore.saveRecipe(original)
            env.recipeViewModel.loadRecipeDetail(original.slug!!)
        }
        var dismissed = false
        compose.setContent {
            ScreenshotTheme {
                EditRecipeDialog(original, env.recipeViewModel, onDismiss = { dismissed = true })
            }
        }
        compose.onNodeWithText("Save").performClick()
        compose.waitForIdle()
        assertTrue(dismissed)
        val saved = runBlocking { env.localStore.loadRecipe(original.slug!!) }!!
        assertEquals(original.recipeIngredient, saved.recipeIngredient)
        assertEquals(original.recipeInstructions, saved.recipeInstructions)
        // No options were loaded, so none of the original associations can be deselected.
        assertEquals(original.recipeCategory, saved.recipeCategory)
        assertEquals(original.tags, saved.tags)
    }

    @Test fun saveFailureRemainsVisibleAndPreservesEditsForRetry() {
        val env = ScreenshotEnv(tmp.root)
        val original = Recipe(id = "saved", slug = "soup", name = "Soup", description = "Original")
        env.recipeViewModel.setLocalMode(true)
        runBlocking { env.localStore.saveRecipe(original) }
        env.localDao.writeFailure = java.io.IOException("disk full")
        var dismissed = false
        compose.setContent {
            ScreenshotTheme {
                EditRecipeDialog(original, env.recipeViewModel, onDismiss = { dismissed = true })
            }
        }
        compose.onNodeWithText("Description").performTextReplacement("Unsaved edit")
        compose.onNodeWithText("Save").performClick()
        compose.waitForIdle()
        assertFalse(dismissed)
        compose.onNodeWithText("Your recipe changes could not be saved. Please try again.").assertIsDisplayed()
        assertEquals("Original", runBlocking { env.localStore.loadRecipe("soup")?.description })
        env.localDao.writeFailure = null
        compose.onNodeWithText("Save").performClick()
        compose.waitForIdle()
        assertTrue(dismissed)
        assertEquals("Unsaved edit", runBlocking { env.localStore.loadRecipe("soup")?.description })
    }

    @Test fun sameNameRowsNavigateToDifferentRecords() {
        val env = ScreenshotEnv(tmp.root)
        runBlocking {
            env.localStore.saveRecipe(Recipe(id = "first", slug = "soup", name = "Soup", description = "First recipe"))
            env.localStore.saveRecipe(Recipe(id = "second", slug = "soup", name = "Soup", description = "Second recipe"))
        }
        env.authViewModel.enterLocalMode()
        val opened = mutableListOf<String>()
        compose.setContent {
            ScreenshotTheme {
                RecipesPane(env.recipeViewModel, env.shoppingViewModel, env.mealPlanViewModel,
                    env.authViewModel, isWideLayout = false, onOpenRecipe = { opened.add(it) })
            }
        }
        compose.onNodeWithText("First recipe").performClick()
        compose.onNodeWithText("Second recipe").performClick()
        compose.waitForIdle()
        assertEquals(2, opened.size)
        assertNotEquals(opened[0], opened[1])
        assertEquals(listOf("first", "second"), runBlocking { opened.map { env.localStore.loadRecipe(it)?.id } })
    }
}
