package com.jackabee.mealie.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.jackabee.mealie.data.settings.ThemePreference

/** Mealie brand orange — matches the iOS accent color. */
val MealieOrange = Color(0xFFE58325)
val MealieOrangeDark = Color(0xFFF0A050)

private val LightColors = lightColorScheme(
    primary = MealieOrange,
    onPrimary = Color.White,
    secondary = MealieOrange,
    onSecondary = Color.White,
    tertiary = MealieOrangeDark,
)

private val DarkColors = darkColorScheme(
    primary = MealieOrangeDark,
    onPrimary = Color.Black,
    secondary = MealieOrangeDark,
    onSecondary = Color.Black,
    tertiary = MealieOrange,
)

@Composable
fun MealieTheme(
    themePreference: ThemePreference = ThemePreference.SYSTEM,
    content: @Composable () -> Unit,
) {
    val darkTheme = when (themePreference) {
        ThemePreference.SYSTEM -> isSystemInDarkTheme()
        ThemePreference.LIGHT -> false
        ThemePreference.DARK -> true
    }
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
