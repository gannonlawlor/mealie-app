package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.data.store.PendingGroceryItem
import com.jackabee.mealie.ui.screens.shopping.ShoppingListDetailScreen
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
class ShoppingListDetailScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun shoppingListDetail_pendingToBuyAndCompleted() {
        val env = ScreenshotEnv(tmp.root)
        val listId = ScreenshotFixtures.GROCERIES_LIST_ID

        // The screen reads pending items from the app container's grocery store
        // (Robolectric SharedPreferences, in-memory) -> "Pending Upload" section.
        val groceryStore = appContainer().localGroceryStore
        groceryStore.addPendingItem(PendingGroceryItem(shoppingListId = listId, note = "Olive oil"), listId)
        groceryStore.addPendingItem(PendingGroceryItem(shoppingListId = listId, note = "Parmesan"), listId)

        // Unchecked -> "To Buy", checked -> "Completed".
        env.api.getShoppingListHandler = { ScreenshotFixtures.groceriesList() }

        composeRule.setContent {
            ScreenshotTheme {
                ShoppingListDetailScreen(
                    listId = listId,
                    shoppingViewModel = env.shoppingViewModel,
                    onBack = {},
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/ShoppingListDetail_sections.png")
    }
}
