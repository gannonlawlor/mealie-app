package com.jackabee.mealie.ui.screens.login

import androidx.compose.runtime.Composable
import com.jackabee.mealie.ui.screens.PlaceholderScreen

@Composable
fun LoginScreen(onLoggedIn: () -> Unit = {}) {
    PlaceholderScreen(title = "Login", subtitle = "Mealie")
}
