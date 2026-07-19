package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.data.model.MealPlanPaginatedResponse
import com.jackabee.mealie.ui.screens.mealplan.MealPlanScreen
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
class MealPlanScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    /**
     * The ViewModel's `today` provider is pinned to [ScreenshotFixtures.weekStart]
     * (Mon 2025-03-10), so the header always reads "Mar 10 - Mar 16" and the
     * screen's own LocalDate.now() today-highlight can never match a day in
     * this past week.
     */
    @Test
    fun mealPlan_weekWithEntries() {
        val env = ScreenshotEnv(tmp.root)
        env.api.getMealPlansHandler = { _, _ ->
            MealPlanPaginatedResponse(items = ScreenshotFixtures.weekEntries())
        }

        composeRule.setContent {
            ScreenshotTheme {
                MealPlanScreen(
                    mealPlanViewModel = env.mealPlanViewModel,
                    recipeViewModel = env.recipeViewModel,
                    onOpenRecipe = {},
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/MealPlan_week.png")
    }
}
