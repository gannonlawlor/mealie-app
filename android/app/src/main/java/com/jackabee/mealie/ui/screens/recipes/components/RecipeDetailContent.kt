package com.jackabee.mealie.ui.screens.recipes.components

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.FileDownloadDone
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Sell
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.jackabee.mealie.data.model.Nutrition
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.RecipeInstruction
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.coroutines.launch

private const val TAG = "RecipeDetailContent"

private val SuccessGreen = Color(0xFF4CAF50)

/**
 * The full recipe detail UI (top bar + scrollable content + sheets/dialogs),
 * shared between the standalone [RecipeDetailScreen][com.jackabee.mealie.ui.screens.recipes.RecipeDetailScreen]
 * (compact, with back arrow) and the wide layout's detail pane.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipeDetailContent(
    slug: String,
    recipeViewModel: RecipeViewModel,
    shoppingViewModel: ShoppingViewModel,
    mealPlanViewModel: MealPlanViewModel,
    showBackButton: Boolean,
    onBack: () -> Unit,
    onDeleted: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val container = rememberAppContainer()
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val recipeState by recipeViewModel.uiState.collectAsStateWithLifecycle()
    val shoppingState by shoppingViewModel.uiState.collectAsStateWithLifecycle()
    val isLocalMode = recipeState.isLocalMode
    // Mirrors iOS: shows the VM's selected recipe (briefly stale while a new
    // slug loads; the edit flow may legitimately change the slug).
    val recipe = recipeState.selectedRecipe

    var showDeleteAlert by remember { mutableStateOf(false) }
    var showEditDialog by remember { mutableStateOf(false) }
    var showAddToMealPlan by remember { mutableStateOf(false) }
    var showListPicker by remember { mutableStateOf(false) }
    var pendingIngredient by remember { mutableStateOf<RecipeIngredient?>(null) }
    var overflowExpanded by remember { mutableStateOf(false) }

    var initialLoadDone by remember(slug) { mutableStateOf(false) }
    LaunchedEffect(slug) {
        recipeViewModel.loadRecipeDetail(slug)
        initialLoadDone = true
    }
    LaunchedEffect(isLocalMode) {
        if (!isLocalMode && shoppingViewModel.uiState.value.shoppingLists.isEmpty()) {
            shoppingViewModel.loadShoppingLists()
        }
    }

    // Keep the screen awake while this screen is shown, if enabled.
    DisposableEffect(Unit) {
        val window = context.findActivity()?.window
        val keepAwake = container.settings.keepScreenAwake
        if (keepAwake) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            if (keepAwake) {
                window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    fun addIngredientToList(listId: String, ingredient: RecipeIngredient) {
        if (container.settings.localGroceryList) {
            shoppingViewModel.addIngredientLocally(listId, ingredient)
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        } else {
            scope.launch {
                if (shoppingViewModel.addIngredientToList(listId, ingredient)) {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                }
            }
        }
    }

    fun onIngredientLongPress(ingredient: RecipeIngredient) {
        val defaultListId = container.settings.defaultShoppingListId
        if (!defaultListId.isNullOrEmpty()) {
            addIngredientToList(defaultListId, ingredient)
        } else {
            pendingIngredient = ingredient
            shoppingViewModel.refreshPendingCounts()
            showListPicker = true
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = recipe?.name ?: "Recipe",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    if (showBackButton) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    val isFavorite = recipeState.favoriteRecipes.contains(slug)
                    IconButton(onClick = {
                        val userId = container.authStore.savedUserId ?: ""
                        scope.launch { recipeViewModel.toggleFavorite(slug, userId) }
                    }) {
                        Icon(
                            imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = if (isFavorite) "Unfavorite" else "Favorite",
                            tint = if (isFavorite) Color.Red else MaterialTheme.colorScheme.onSurface,
                        )
                    }

                    val recipeId = recipe?.id
                    if (!isLocalMode && recipeId != null) {
                        val isOffline = recipeState.offlineRecipeIds.contains(recipeId)
                        if (recipeState.isSavingOffline) {
                            CircularProgressIndicator(
                                strokeWidth = 2.dp,
                                modifier = Modifier
                                    .padding(horizontal = 12.dp)
                                    .size(20.dp),
                            )
                        } else {
                            IconButton(onClick = {
                                scope.launch { recipeViewModel.toggleOffline(slug, recipeId) }
                            }) {
                                Icon(
                                    imageVector = if (isOffline) Icons.Outlined.FileDownloadDone else Icons.Outlined.FileDownload,
                                    contentDescription = if (isOffline) "Remove offline copy" else "Save offline",
                                    tint = if (isOffline) SuccessGreen else MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        }
                    }

                    Box {
                        IconButton(onClick = { overflowExpanded = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = "More options")
                        }
                        DropdownMenu(
                            expanded = overflowExpanded,
                            onDismissRequest = { overflowExpanded = false },
                        ) {
                            if (!isLocalMode) {
                                DropdownMenuItem(
                                    text = { Text("Add to Meal Plan") },
                                    leadingIcon = { Icon(Icons.Outlined.CalendarMonth, contentDescription = null) },
                                    onClick = {
                                        overflowExpanded = false
                                        showAddToMealPlan = true
                                    },
                                )
                            }
                            DropdownMenuItem(
                                text = { Text("Edit Recipe") },
                                leadingIcon = { Icon(Icons.Outlined.Edit, contentDescription = null) },
                                onClick = {
                                    overflowExpanded = false
                                    showEditDialog = true
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Delete Recipe", color = MaterialTheme.colorScheme.error) },
                                leadingIcon = {
                                    Icon(
                                        Icons.Outlined.Delete,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.error,
                                    )
                                },
                                onClick = {
                                    overflowExpanded = false
                                    showDeleteAlert = true
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier
            .padding(padding)
            .fillMaxSize()
        ) {
            when {
                recipeState.isLoadingDetail || (!initialLoadDone && recipe == null) -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        CircularProgressIndicator()
                        Text(
                            text = "Loading recipe...",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 12.dp),
                        )
                    }
                }

                recipe != null -> {
                    RecipeDetailBody(
                        recipe = recipe,
                        isLocalMode = isLocalMode,
                        heroModel = recipe.id?.let { heroImageModel(container, isLocalMode, it) },
                        onIngredientLongPress = ::onIngredientLongPress,
                    )
                }

                else -> {
                    Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                        Text(
                            text = "Recipe not found",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }

    if (showDeleteAlert) {
        AlertDialog(
            onDismissRequest = { showDeleteAlert = false },
            title = { Text("Delete Recipe") },
            text = { Text("Are you sure you want to delete this recipe? This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteAlert = false
                    scope.launch {
                        if (recipeViewModel.deleteRecipe(slug)) {
                            onDeleted()
                        }
                    }
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAlert = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    if (showEditDialog && recipe != null) {
        EditRecipeDialog(
            recipe = recipe,
            recipeViewModel = recipeViewModel,
            onDismiss = { showEditDialog = false },
        )
    }

    if (showAddToMealPlan && recipe?.id != null) {
        AddToMealPlanSheet(
            mealPlanViewModel = mealPlanViewModel,
            recipeId = recipe.id ?: "",
            onDismiss = { showAddToMealPlan = false },
        )
    }

    if (showListPicker) {
        ShoppingListPickerSheet(
            shoppingLists = shoppingState.shoppingLists,
            pendingItemCounts = shoppingState.pendingItemCounts,
            onPick = { listId, setAsDefault ->
                if (setAsDefault) {
                    container.settings.defaultShoppingListId = listId
                    container.settings.defaultShoppingListName =
                        shoppingState.shoppingLists.firstOrNull { it.id == listId }?.name
                }
                pendingIngredient?.let { addIngredientToList(listId, it) }
                pendingIngredient = null
                showListPicker = false
            },
            onDismiss = {
                pendingIngredient = null
                showListPicker = false
            },
        )
    }
}

@Composable
private fun RecipeDetailBody(
    recipe: Recipe,
    isLocalMode: Boolean,
    heroModel: Any?,
    onIngredientLongPress: (RecipeIngredient) -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    var isDescriptionExpanded by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hero image
        if (recipe.id != null) {
            if (heroModel != null) {
                AsyncImage(
                    model = heroModel,
                    contentDescription = recipe.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(250.dp),
                )
            } else {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(250.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Image,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(48.dp),
                    )
                }
            }
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
        ) {
            // Title
            Text(
                text = recipe.name ?: "",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )

            // Description with Show more/Show less
            val description = recipe.description
            if (!description.isNullOrEmpty()) {
                Column {
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = if (isDescriptionExpanded) Int.MAX_VALUE else 3,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = if (isDescriptionExpanded) "Show less" else "Show more",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .padding(top = 4.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .clickable { isDescriptionExpanded = !isDescriptionExpanded },
                    )
                }
            }

            // Original recipe link
            val orgURL = recipe.orgURL
            if (!orgURL.isNullOrEmpty()) {
                Text(
                    text = "View Original Recipe ↗",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.clickable {
                        try {
                            uriHandler.openUri(orgURL)
                        } catch (e: Exception) {
                            AppLog.w(TAG, "Failed to open original recipe URL: $e", e)
                        }
                    },
                )
            }

            // Time & yield cards
            TimeInfoSection(recipe)

            // Category & tag chips
            TagChipsSection(recipe)

            // Ingredients
            val ingredients = recipe.recipeIngredient.orEmpty()
            if (ingredients.isNotEmpty()) {
                IngredientsSection(
                    ingredients = ingredients,
                    isLocalMode = isLocalMode,
                    onIngredientLongPress = onIngredientLongPress,
                )
            }

            // Instructions
            val instructions = recipe.recipeInstructions.orEmpty()
            if (instructions.isNotEmpty()) {
                InstructionsSection(instructions)
            }

            // Nutrition
            recipe.nutrition?.let { NutritionSection(it) }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
private fun TimeInfoSection(recipe: Recipe) {
    val items = listOf(
        "Prep" to (recipe.prepTime ?: ""),
        "Cook" to (recipe.performTime ?: ""),
        "Total" to (recipe.totalTime ?: ""),
        "Yield" to (recipe.recipeYield ?: ""),
    ).filter { it.second.isNotEmpty() }

    if (items.isEmpty()) return

    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
        items.forEach { (label, value) ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(vertical = 8.dp, horizontal = 4.dp),
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = formatDuration(value),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun TagChipsSection(recipe: Recipe) {
    val chips: List<Pair<Boolean, String>> =
        recipe.recipeCategory.orEmpty().map { true to (it.name ?: "") } +
            recipe.tags.orEmpty().map { false to (it.name ?: "") }

    if (chips.isEmpty()) return

    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
    ) {
        chips.forEach { (isCategory, name) ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Icon(
                    imageVector = if (isCategory) Icons.Outlined.Folder else Icons.Outlined.Sell,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .padding(end = 4.dp)
                        .size(12.dp),
                )
                Text(text = name, style = MaterialTheme.typography.labelMedium)
            }
        }
    }
}

@Composable
private fun IngredientsSection(
    ingredients: List<RecipeIngredient>,
    isLocalMode: Boolean,
    onIngredientLongPress: (RecipeIngredient) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "Ingredients",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            if (!isLocalMode) {
                Text(
                    text = "Long press to add",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        ingredients.forEach { ingredient ->
            val title = ingredient.title
            if (!title.isNullOrEmpty()) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            IngredientRow(
                ingredient = ingredient,
                longPressEnabled = !isLocalMode,
                onLongPressComplete = onIngredientLongPress,
            )
        }
    }
}

@Composable
private fun InstructionsSection(instructions: List<RecipeInstruction>) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = "Instructions",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        instructions.forEachIndexed { index, instruction ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                val title = instruction.title
                if (!title.isNullOrEmpty()) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                Row(verticalAlignment = Alignment.Top) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary),
                    ) {
                        Text(
                            text = "${index + 1}",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = instruction.text ?: "",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun NutritionSection(nutrition: Nutrition) {
    val items = listOf(
        "Calories" to (nutrition.calories ?: ""),
        "Fat" to (nutrition.fatContent ?: ""),
        "Protein" to (nutrition.proteinContent ?: ""),
        "Carbs" to (nutrition.carbohydrateContent ?: ""),
        "Fiber" to (nutrition.fiberContent ?: ""),
        "Sugar" to (nutrition.sugarContent ?: ""),
    ).filter { it.second.isNotEmpty() }

    if (items.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Nutrition",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        items.chunked(3).forEach { rowItems ->
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                rowItems.forEach { (label, value) ->
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .padding(8.dp),
                    ) {
                        Text(
                            text = value,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                repeat(3 - rowItems.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

/** Unwraps ContextWrappers to find the hosting Activity (for window flags). */
private fun Context.findActivity(): Activity? {
    var current: Context = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
