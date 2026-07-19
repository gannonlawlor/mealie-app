package com.jackabee.mealie.ui.screens.recipes

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackabee.mealie.ui.screens.recipes.components.rememberAppContainer
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel

/**
 * Legacy compact-layout entry point kept for the pre-integration nav host.
 * Integration should use [RecipesPane] directly with shared ViewModels.
 */
@Composable
fun RecipesScreen(onRecipeSelected: (String) -> Unit = {}) {
    val container = rememberAppContainer()
    RecipesPane(
        recipeViewModel = viewModel(factory = RecipeViewModel.factory(container)),
        shoppingViewModel = viewModel(factory = ShoppingViewModel.factory(container)),
        mealPlanViewModel = viewModel(factory = MealPlanViewModel.factory(container)),
        authViewModel = viewModel(factory = AuthViewModel.factory(container)),
        isWideLayout = false,
        onOpenRecipe = onRecipeSelected,
    )
}
