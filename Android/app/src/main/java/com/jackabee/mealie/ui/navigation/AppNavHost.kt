package com.jackabee.mealie.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.jackabee.mealie.ui.screens.login.LoginScreen
import com.jackabee.mealie.ui.screens.mealplan.MealPlanScreen
import com.jackabee.mealie.ui.screens.recipes.RecipeDetailScreen
import com.jackabee.mealie.ui.screens.recipes.RecipesScreen
import com.jackabee.mealie.ui.screens.settings.SettingsScreen
import com.jackabee.mealie.ui.screens.shopping.ShoppingDetailScreen
import com.jackabee.mealie.ui.screens.shopping.ShoppingScreen

/** Route constants for the app's navigation graph. */
object Routes {
    const val LOGIN = "login"
    const val RECIPES = "recipes"
    const val RECIPE_DETAIL = "recipeDetail/{slug}"
    const val MEAL_PLAN = "mealplan"
    const val SHOPPING = "shopping"
    const val SHOPPING_DETAIL = "shoppingDetail/{id}"
    const val SETTINGS = "settings"

    fun recipeDetail(slug: String) = "recipeDetail/$slug"
    fun shoppingDetail(id: String) = "shoppingDetail/$id"
}

@Composable
fun AppNavHost(
    navController: NavHostController = rememberNavController(),
    startDestination: String = Routes.LOGIN,
) {
    NavHost(navController = navController, startDestination = startDestination) {
        composable(Routes.LOGIN) {
            LoginScreen(
                onLoggedIn = {
                    navController.navigate(Routes.RECIPES) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                }
            )
        }
        composable(Routes.RECIPES) {
            RecipesScreen(
                onRecipeSelected = { slug -> navController.navigate(Routes.recipeDetail(slug)) },
            )
        }
        composable(
            Routes.RECIPE_DETAIL,
            arguments = listOf(navArgument("slug") { type = NavType.StringType }),
        ) { backStackEntry ->
            RecipeDetailScreen(
                slug = backStackEntry.arguments?.getString("slug").orEmpty(),
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.MEAL_PLAN) {
            MealPlanScreen()
        }
        composable(Routes.SHOPPING) {
            ShoppingScreen(
                onListSelected = { id -> navController.navigate(Routes.shoppingDetail(id)) },
            )
        }
        composable(
            Routes.SHOPPING_DETAIL,
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { backStackEntry ->
            ShoppingDetailScreen(
                listId = backStackEntry.arguments?.getString("id").orEmpty(),
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS) {
            SettingsScreen()
        }
    }
}
