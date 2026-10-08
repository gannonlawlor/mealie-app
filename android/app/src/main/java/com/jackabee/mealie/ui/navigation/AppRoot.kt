package com.jackabee.mealie.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.window.core.layout.WindowWidthSizeClass
import com.jackabee.mealie.di.AppContainer
import com.jackabee.mealie.ui.screens.login.LoginScreen
import com.jackabee.mealie.ui.screens.mealplan.MealPlanScreen
import com.jackabee.mealie.ui.screens.recipes.RecipeDetailScreen
import com.jackabee.mealie.ui.screens.recipes.RecipesPane
import com.jackabee.mealie.ui.screens.settings.SettingsScreen
import com.jackabee.mealie.ui.screens.shopping.ShoppingListDetailScreen
import com.jackabee.mealie.ui.screens.shopping.ShoppingPane
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Route constants for the app's navigation graph. */
object Routes {
    const val RECIPES = "recipes"
    const val RECIPE_DETAIL = "recipeDetail/{slug}"
    const val MEAL_PLAN = "mealplan"
    const val SHOPPING = "shopping"
    const val SHOPPING_DETAIL = "shoppingDetail/{id}"
    const val SETTINGS = "settings"

    fun recipeDetail(slug: String) = "recipeDetail/$slug"
    fun shoppingDetail(id: String) = "shoppingDetail/$id"
}

/** Top-level navigation destinations (bottom bar on compact, rail on medium/expanded). */
private data class TopDestination(val route: String, val label: String, val icon: ImageVector)

/**
 * Detached scope for the background recipe sync, mirroring the Swift
 * `Task.detached { await RecipeSyncService.shared.syncAll() }` — the sync
 * should outlive the composition that started it.
 */
private val syncScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

/**
 * Root of the UI: shows the login flow when unauthenticated, otherwise the
 * adaptive main scaffold. Also mirrors the iOS ContentView side effects that
 * react to the server-connection state.
 */
@Composable
fun AppRoot(
    container: AppContainer,
    authViewModel: AuthViewModel,
    recipeViewModel: RecipeViewModel,
    mealPlanViewModel: MealPlanViewModel,
    shoppingViewModel: ShoppingViewModel,
    importEvents: StateFlow<Long>,
) {
    val authState by authViewModel.uiState.collectAsStateWithLifecycle()

    // Mirrors iOS ContentView .task / .onChange(of: isServerConnected).
    // Also drains share URLs queued while signed out: remove-before-import so a
    // failed import shows the normal error banner instead of re-queuing in a loop.
    // Keyed on both flags so local-mode entry (authenticated flips, connected
    // stays false) drains from this one site just like server login does.
    LaunchedEffect(authState.isServerConnected, authState.isAuthenticated) {
        val connected = authState.isServerConnected
        recipeViewModel.setLocalMode(!connected)
        if (authState.isAuthenticated) {
            val pending = container.authStore.pendingImportURLs()
            for (url in pending) {
                container.authStore.removePendingImportURL(url)
                recipeViewModel.updateImportURL(url)
                recipeViewModel.importFromURL()
            }
        }
        if (connected) {
            authViewModel.loadCurrentUser()
            recipeViewModel.loadFavorites(authViewModel.uiState.value.currentUser)
            recipeViewModel.loadOfflineIds()
            recipeViewModel.loadRecipes(reset = true)
            syncScope.launch { container.recipeSyncService.syncAll() }
        } else {
            recipeViewModel.loadFavorites(null)
            recipeViewModel.loadRecipes(reset = true)
        }
    }

    if (!authState.isAuthenticated) {
        LoginScreen(authViewModel = authViewModel)
    } else {
        MainScaffold(
            isServerConnected = authState.isServerConnected,
            authViewModel = authViewModel,
            recipeViewModel = recipeViewModel,
            mealPlanViewModel = mealPlanViewModel,
            shoppingViewModel = shoppingViewModel,
            importEvents = importEvents,
        )
    }
}

@Composable
private fun MainScaffold(
    isServerConnected: Boolean,
    authViewModel: AuthViewModel,
    recipeViewModel: RecipeViewModel,
    mealPlanViewModel: MealPlanViewModel,
    shoppingViewModel: ShoppingViewModel,
    importEvents: StateFlow<Long>,
) {
    val navController = rememberNavController()
    val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass
    val widthClass = windowSizeClass.windowWidthSizeClass
    val isWideLayout = widthClass == WindowWidthSizeClass.EXPANDED
    val layoutType = if (widthClass == WindowWidthSizeClass.COMPACT) {
        NavigationSuiteType.NavigationBar
    } else {
        NavigationSuiteType.NavigationRail
    }

    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    val destinations = buildList {
        add(TopDestination(Routes.RECIPES, "Recipes", Icons.AutoMirrored.Filled.MenuBook))
        if (isServerConnected) {
            add(TopDestination(Routes.MEAL_PLAN, "Meal Plan", Icons.Filled.CalendarMonth))
            add(TopDestination(Routes.SHOPPING, "Shopping", Icons.Filled.ShoppingCart))
        }
        add(TopDestination(Routes.SETTINGS, "Settings", Icons.Filled.Settings))
    }

    // On disconnect, leave the server-only tabs (mirrors iOS switching to Recipes).
    LaunchedEffect(isServerConnected) {
        if (!isServerConnected) {
            val route = navController.currentDestination?.route
            if (route == Routes.MEAL_PLAN || route == Routes.SHOPPING || route == Routes.SHOPPING_DETAIL) {
                navController.navigateToTopLevel(Routes.RECIPES)
            }
        }
    }

    // A share/view import intent switches to the Recipes destination.
    LaunchedEffect(Unit) {
        importEvents.collect { event ->
            if (event > 0L) {
                navController.navigateToTopLevel(Routes.RECIPES)
            }
        }
    }

    NavigationSuiteScaffold(
        layoutType = layoutType,
        navigationSuiteItems = {
            destinations.forEach { destination ->
                item(
                    selected = currentRoute == destination.route,
                    onClick = { navController.navigateToTopLevel(destination.route) },
                    icon = { Icon(destination.icon, contentDescription = destination.label) },
                    label = { Text(destination.label) },
                )
            }
        },
    ) {
        NavHost(navController = navController, startDestination = Routes.RECIPES) {
            composable(Routes.RECIPES) {
                RecipesPane(
                    recipeViewModel = recipeViewModel,
                    shoppingViewModel = shoppingViewModel,
                    mealPlanViewModel = mealPlanViewModel,
                    authViewModel = authViewModel,
                    isWideLayout = isWideLayout,
                    onOpenRecipe = { slug -> navController.navigate(Routes.recipeDetail(slug)) },
                )
            }
            composable(
                Routes.RECIPE_DETAIL,
                arguments = listOf(navArgument("slug") { type = NavType.StringType }),
            ) { entry ->
                RecipeDetailScreen(
                    slug = entry.arguments?.getString("slug").orEmpty(),
                    recipeViewModel = recipeViewModel,
                    shoppingViewModel = shoppingViewModel,
                    mealPlanViewModel = mealPlanViewModel,
                    onBack = { navController.popBackStack() },
                    onDeleted = { navController.popBackStack() },
                )
            }
            composable(Routes.MEAL_PLAN) {
                MealPlanScreen(
                    mealPlanViewModel = mealPlanViewModel,
                    recipeViewModel = recipeViewModel,
                    onOpenRecipe = { slug -> navController.navigate(Routes.recipeDetail(slug)) },
                )
            }
            composable(Routes.SHOPPING) {
                ShoppingPane(
                    shoppingViewModel = shoppingViewModel,
                    isWideLayout = isWideLayout,
                    onOpenList = { id -> navController.navigate(Routes.shoppingDetail(id)) },
                )
            }
            composable(
                Routes.SHOPPING_DETAIL,
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
            ) { entry ->
                ShoppingListDetailScreen(
                    listId = entry.arguments?.getString("id").orEmpty(),
                    shoppingViewModel = shoppingViewModel,
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.SETTINGS) {
                SettingsScreen(authViewModel = authViewModel, shoppingViewModel = shoppingViewModel)
            }
        }
    }
}

private fun NavHostController.navigateToTopLevel(route: String) {
    navigate(route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}
