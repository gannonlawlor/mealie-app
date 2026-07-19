package com.jackabee.mealie.ui.screens.shopping

import androidx.compose.runtime.Composable
import com.jackabee.mealie.ui.screens.PlaceholderScreen

@Composable
fun ShoppingDetailScreen(listId: String, onBack: () -> Unit = {}) {
    PlaceholderScreen(title = "Shopping List", subtitle = listId)
}
