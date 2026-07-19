package com.jackabee.mealie.ui.screens.recipes

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.ui.screens.recipes.components.DuplicateRecipeDialog
import com.jackabee.mealie.ui.screens.recipes.components.EditRecipeDialog
import com.jackabee.mealie.ui.screens.recipes.components.ImportRecipeSheet
import com.jackabee.mealie.ui.screens.recipes.components.RecipeDetailContent
import com.jackabee.mealie.ui.screens.recipes.components.RecipeListContent
import com.jackabee.mealie.ui.screens.recipes.components.rememberAppContainer
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel

/**
 * The recipes feature root.
 *
 * Compact ([isWideLayout] = false): full recipes list screen; row taps call
 * [onOpenRecipe] so the nav host can push the detail route.
 *
 * Wide ([isWideLayout] = true): two-pane layout with a 340dp list pane and a
 * detail pane driven by internal selection state (onOpenRecipe is not used).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipesPane(
    recipeViewModel: RecipeViewModel,
    shoppingViewModel: ShoppingViewModel,
    mealPlanViewModel: MealPlanViewModel,
    authViewModel: AuthViewModel,
    isWideLayout: Boolean,
    onOpenRecipe: (String) -> Unit,
) {
    val container = rememberAppContainer()
    val recipeState by recipeViewModel.uiState.collectAsStateWithLifecycle()
    val authState by authViewModel.uiState.collectAsStateWithLifecycle()

    var showFavoritesOnly by rememberSaveable { mutableStateOf(false) }
    var showImportSheet by rememberSaveable { mutableStateOf(false) }
    var editingCreatedRecipe by remember { mutableStateOf<Recipe?>(null) }
    var selectedSlug by rememberSaveable { mutableStateOf<String?>(null) }

    val userId = container.authStore.savedUserId ?: authState.currentUser?.id ?: ""

    // Keep the recipe VM's mode in sync with auth, then do the initial load.
    LaunchedEffect(authState.isLocalMode) {
        recipeViewModel.setLocalMode(authState.isLocalMode)
        if (recipeViewModel.uiState.value.recipes.isEmpty()) {
            recipeViewModel.loadRecipes(reset = true)
            recipeViewModel.loadCategories()
            recipeViewModel.loadTags()
        }
        if (!authState.isLocalMode) {
            recipeViewModel.loadOfflineIds()
        }
        recipeViewModel.loadFavorites(authState.currentUser)
    }
    LaunchedEffect(authState.currentUser) {
        recipeViewModel.loadFavorites(authState.currentUser)
    }

    val displayedRecipes = if (showFavoritesOnly) {
        recipeState.recipes.filter { recipeState.favoriteRecipes.contains(it.slug ?: "") }
    } else {
        recipeState.recipes
    }

    fun openRecipe(slug: String) {
        if (isWideLayout) {
            selectedSlug = slug
        } else {
            onOpenRecipe(slug)
        }
        if (recipeState.searchText.isNotEmpty()) {
            recipeViewModel.updateSearchText("")
        }
    }

    val topBarActions: @Composable () -> Unit = {
        IconButton(onClick = { showFavoritesOnly = !showFavoritesOnly }) {
            Icon(
                imageVector = if (showFavoritesOnly) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                contentDescription = if (showFavoritesOnly) "Show all recipes" else "Show favorites only",
                tint = if (showFavoritesOnly) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
        }
        IconButton(onClick = { showImportSheet = true }) {
            Icon(Icons.Filled.Add, contentDescription = "Add recipe")
        }
    }

    if (isWideLayout) {
        Row(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .width(340.dp)
                    .fillMaxHeight(),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, end = 4.dp, top = 12.dp, bottom = 4.dp),
                ) {
                    Text(
                        text = "Recipes",
                        style = MaterialTheme.typography.headlineSmall,
                        modifier = Modifier.weight(1f),
                    )
                    topBarActions()
                }
                RecipeListContent(
                    recipeViewModel = recipeViewModel,
                    state = recipeState,
                    container = container,
                    displayedRecipes = displayedRecipes,
                    showFavoritesOnly = showFavoritesOnly,
                    selectedSlug = selectedSlug,
                    userId = userId,
                    onRecipeClick = { openRecipe(it) },
                )
            }

            VerticalDivider()

            Box(modifier = Modifier.weight(1f)) {
                val slug = selectedSlug
                if (slug != null) {
                    key(slug) {
                        RecipeDetailContent(
                            slug = slug,
                            recipeViewModel = recipeViewModel,
                            shoppingViewModel = shoppingViewModel,
                            mealPlanViewModel = mealPlanViewModel,
                            showBackButton = false,
                            onBack = {},
                            onDeleted = { selectedSlug = null },
                        )
                    }
                } else {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.align(Alignment.Center),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Outlined.MenuBook,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(48.dp),
                        )
                        Text(
                            text = "Select a recipe",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 12.dp),
                        )
                    }
                }
            }
        }
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Recipes") },
                    actions = { topBarActions() },
                )
            },
        ) { padding ->
            RecipeListContent(
                recipeViewModel = recipeViewModel,
                state = recipeState,
                container = container,
                displayedRecipes = displayedRecipes,
                showFavoritesOnly = showFavoritesOnly,
                selectedSlug = null,
                userId = userId,
                onRecipeClick = { openRecipe(it) },
                modifier = Modifier.padding(padding),
            )
        }
    }

    if (showImportSheet) {
        ImportRecipeSheet(
            recipeViewModel = recipeViewModel,
            state = recipeState,
            onDismiss = { showImportSheet = false },
            onRecipeCreated = { recipe ->
                showImportSheet = false
                editingCreatedRecipe = recipe
            },
        )
    }

    if (recipeState.showDuplicateAlert) {
        DuplicateRecipeDialog(
            recipeViewModel = recipeViewModel,
            state = recipeState,
            onResolved = { showImportSheet = false },
        )
    }

    editingCreatedRecipe?.let { recipe ->
        EditRecipeDialog(
            recipe = recipe,
            recipeViewModel = recipeViewModel,
            onDismiss = { editingCreatedRecipe = null },
        )
    }
}
