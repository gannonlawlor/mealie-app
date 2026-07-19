package com.jackabee.mealie.ui.screens.mealplan

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel

// STUB: the real implementation is produced by another agent with this exact
// signature; this placeholder file is discarded at merge.
@Composable
fun MealPlanScreen(
    mealPlanViewModel: MealPlanViewModel,
    recipeViewModel: RecipeViewModel,
    onOpenRecipe: (String) -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Meal Plan")
    }
}
