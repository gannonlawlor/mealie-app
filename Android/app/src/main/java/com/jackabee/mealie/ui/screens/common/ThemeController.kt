package com.jackabee.mealie.ui.screens.common

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackabee.mealie.data.settings.ThemePreference

/**
 * App-wide theme state. Seeded from [com.jackabee.mealie.data.settings.AppSettings]
 * in MainActivity, updated live by the Settings screen's theme picker.
 */
object ThemeController {
    var theme: ThemePreference by mutableStateOf(ThemePreference.SYSTEM)
}
