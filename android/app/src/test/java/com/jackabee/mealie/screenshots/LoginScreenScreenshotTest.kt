package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.ui.screens.login.LoginScreen
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
class LoginScreenScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun loginScreen_serverSetup() {
        val env = ScreenshotEnv(tmp.root)
        // A previously used server plus a partially typed new URL.
        env.authStore.addSavedServer("https://demo.mealie.example", "chef@example.com")
        env.authViewModel.updateServerURL("mealie.home.local")

        composeRule.setContent {
            ScreenshotTheme {
                LoginScreen(authViewModel = env.authViewModel)
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/LoginScreen_serverSetup.png")
    }

    @Test
    fun loginScreen_loginForm() {
        val env = ScreenshotEnv(tmp.root)
        env.authViewModel.updateServerURL("https://demo.mealie.example")
        // Fake API answers getAppInfo synchronously, flipping to the login form.
        runBlocking { env.authViewModel.validateServer() }
        env.authViewModel.updateEmail("chef@example.com")
        env.authViewModel.updatePassword("super-secret")

        composeRule.setContent {
            ScreenshotTheme {
                LoginScreen(authViewModel = env.authViewModel)
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/LoginScreen_loginForm.png")
    }
}
