package com.jackabee.mealie.ui.screens.recipes

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackabee.mealie.ui.screens.recipes.components.RecipeDetailContent
import com.jackabee.mealie.ui.screens.recipes.components.rememberAppContainer
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel

/**
 * Standalone recipe detail screen (compact layout navigation destination).
 *
 * The ViewModel parameters have defaults only so the pre-integration nav host
 * keeps compiling; integration should always pass the shared instances.
 */
@Composable
fun RecipeDetailScreen(
    slug: String,
    recipeViewModel: RecipeViewModel = viewModel(factory = RecipeViewModel.factory(rememberAppContainer())),
    shoppingViewModel: ShoppingViewModel = viewModel(factory = ShoppingViewModel.factory(rememberAppContainer())),
    mealPlanViewModel: MealPlanViewModel = viewModel(factory = MealPlanViewModel.factory(rememberAppContainer())),
    onBack: () -> Unit,
    onDeleted: () -> Unit = onBack,
) {
    RecipeDetailContent(
        slug = slug,
        recipeViewModel = recipeViewModel,
        shoppingViewModel = shoppingViewModel,
        mealPlanViewModel = mealPlanViewModel,
        showBackButton = true,
        onBack = onBack,
        onDeleted = onDeleted,
    )
}
