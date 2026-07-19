package com.jackabee.mealie.ui.screens.recipes

import androidx.compose.runtime.Composable
import com.jackabee.mealie.ui.screens.PlaceholderScreen

@Composable
fun RecipeDetailScreen(slug: String, onBack: () -> Unit = {}) {
    PlaceholderScreen(title = "Recipe", subtitle = slug)
}
