package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.ui.screens.settings.SettingsScreen
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
class SettingsScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun settings_localMode() {
        val env = ScreenshotEnv(tmp.root)
        env.authViewModel.enterLocalMode()

        composeRule.setContent {
            ScreenshotTheme {
                SettingsScreen(
                    authViewModel = env.authViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/Settings_localMode.png")
    }
}
