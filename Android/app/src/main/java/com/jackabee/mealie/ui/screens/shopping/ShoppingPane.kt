package com.jackabee.mealie.ui.screens.shopping

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel

// STUB: the real implementation is produced by another agent with this exact
// signature; this placeholder file is discarded at merge.
@Composable
fun ShoppingPane(
    shoppingViewModel: ShoppingViewModel,
    isWideLayout: Boolean,
    onOpenList: (String) -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Shopping")
    }
}
