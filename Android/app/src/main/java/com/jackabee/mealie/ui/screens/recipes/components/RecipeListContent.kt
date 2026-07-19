package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Sell
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.di.AppContainer
import com.jackabee.mealie.ui.viewmodel.RecipeUiState
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import kotlinx.coroutines.launch

/**
 * The recipes list column shared by the compact screen and the wide layout's
 * list pane: search field, matching-tag suggestions, category/tag filter
 * chips, error banner, and the recipe list with pull-to-refresh and infinite
 * scroll.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipeListContent(
    recipeViewModel: RecipeViewModel,
    state: RecipeUiState,
    container: AppContainer,
    displayedRecipes: List<RecipeSummary>,
    showFavoritesOnly: Boolean,
    selectedSlug: String?,
    userId: String,
    onRecipeClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val keyboard = LocalSoftwareKeyboardController.current
    var isRefreshing by remember { mutableStateOf(false) }
    var dismissedError by remember { mutableStateOf<String?>(null) }

    Column(modifier = modifier.fillMaxSize()) {
        // Search field
        OutlinedTextField(
            value = state.searchText,
            onValueChange = { recipeViewModel.updateSearchText(it) },
            placeholder = { Text("Search recipes...") },
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            trailingIcon = {
                if (state.searchText.isNotEmpty()) {
                    IconButton(onClick = { recipeViewModel.updateSearchText("") }) {
                        Icon(Icons.Filled.Close, contentDescription = "Clear search")
                    }
                }
            },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {
                keyboard?.hide()
                scope.launch { recipeViewModel.search() }
            }),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )

        // Matching tag suggestions while searching
        if (state.matchingTags.isNotEmpty() && state.searchText.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                state.matchingTags.forEach { tag ->
                    MealieChip(
                        label = tag.name ?: "",
                        selected = false,
                        onClick = {
                            recipeViewModel.selectTag(tag)
                            recipeViewModel.updateSearchText("")
                        },
                        icon = {
                            Icon(
                                imageVector = Icons.Outlined.Sell,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .padding(end = 4.dp)
                                    .size(14.dp),
                            )
                        },
                    )
                }
            }
        }

        // Category/tag filter chips
        if (state.categories.isNotEmpty() || state.tags.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                state.categories.forEach { category ->
                    val selected = state.selectedCategory?.id == category.id
                    MealieChip(
                        label = category.name ?: "",
                        selected = selected,
                        onClick = {
                            recipeViewModel.selectCategory(if (selected) null else category)
                            scope.launch { recipeViewModel.loadRecipes(reset = true) }
                        },
                        icon = {
                            Icon(
                                imageVector = Icons.Outlined.Folder,
                                contentDescription = null,
                                tint = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .padding(end = 4.dp)
                                    .size(14.dp),
                            )
                        },
                    )
                }
                state.tags.forEach { tag ->
                    val selected = state.selectedTag?.id == tag.id
                    MealieChip(
                        label = tag.name ?: "",
                        selected = selected,
                        onClick = {
                            recipeViewModel.selectTag(if (selected) null else tag)
                            scope.launch { recipeViewModel.loadRecipes(reset = true) }
                        },
                        icon = {
                            Icon(
                                imageVector = Icons.Outlined.Sell,
                                contentDescription = null,
                                tint = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .padding(end = 4.dp)
                                    .size(14.dp),
                            )
                        },
                    )
                }
            }
        }

        // Error banner
        if (state.errorMessage.isNotEmpty() && state.errorMessage != dismissedError) {
            ErrorBanner(
                message = state.errorMessage,
                detail = state.errorDetail,
                onDismiss = { dismissedError = state.errorMessage },
            )
        }

        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = {
                scope.launch {
                    isRefreshing = true
                    recipeViewModel.loadRecipes(reset = true)
                    isRefreshing = false
                }
            },
            modifier = Modifier.weight(1f),
        ) {
            when {
                state.isLoading && state.recipes.isEmpty() -> {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        CircularProgressIndicator()
                    }
                }

                displayedRecipes.isEmpty() -> {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        Text(
                            text = if (showFavoritesOnly) "No favorite recipes" else "No recipes found",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                else -> {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        items(
                            count = displayedRecipes.size,
                            key = { index -> displayedRecipes[index].id ?: displayedRecipes[index].slug ?: index.toString() },
                        ) { index ->
                            val recipe = displayedRecipes[index]
                            val slug = recipe.slug ?: ""
                            val recipeId = recipe.id ?: ""
                            RecipeRow(
                                recipe = recipe,
                                imageModel = recipe.id?.let {
                                    thumbnailImageModel(container, state.isLocalMode, it)
                                },
                                isSavedOffline = !state.isLocalMode && state.offlineRecipeIds.contains(recipeId),
                                isFavorite = state.favoriteRecipes.contains(slug),
                                isSelected = selectedSlug != null && selectedSlug == recipe.slug,
                                showOfflineAction = !state.isLocalMode,
                                onClick = { if (slug.isNotEmpty()) onRecipeClick(slug) },
                                onToggleFavorite = {
                                    if (slug.isNotEmpty()) {
                                        scope.launch { recipeViewModel.toggleFavorite(slug, userId) }
                                    }
                                },
                                onToggleOffline = {
                                    if (slug.isNotEmpty() && recipeId.isNotEmpty()) {
                                        scope.launch { recipeViewModel.toggleOffline(slug, recipeId) }
                                    }
                                },
                                onDelete = {
                                    if (slug.isNotEmpty()) {
                                        scope.launch { recipeViewModel.deleteRecipe(slug) }
                                    }
                                },
                            )
                        }

                        // Infinite scroll: when the loader row becomes visible, load the next page.
                        if (state.currentPage < state.totalPages) {
                            item(key = "next-page-loader") {
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 16.dp),
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                                }
                                LaunchedEffect(state.currentPage) {
                                    recipeViewModel.loadNextPage()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
