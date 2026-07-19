package com.jackabee.mealie.ui.screens.recipes

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel

// STUB: the real implementation is produced by another agent with this exact
// signature; this placeholder file is discarded at merge.
@Composable
fun RecipeDetailScreen(
    slug: String,
    recipeViewModel: RecipeViewModel,
    shoppingViewModel: ShoppingViewModel,
    mealPlanViewModel: MealPlanViewModel,
    onBack: () -> Unit,
    onDeleted: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Recipe: $slug")
    }
}
