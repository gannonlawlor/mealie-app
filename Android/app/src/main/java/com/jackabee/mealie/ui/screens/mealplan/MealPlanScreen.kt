package com.jackabee.mealie.ui.screens.mealplan

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.EmojiFoodBeverage
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealType
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch

/**
 * Transitional no-arg overload so existing navigation wiring keeps compiling until
 * integration passes the shared ViewModels and recipe navigation callback.
 */
@Composable
fun MealPlanScreen() {
    val container = (LocalContext.current.applicationContext as MealieApplication).container
    val mealPlanViewModel: MealPlanViewModel = viewModel(factory = MealPlanViewModel.factory(container))
    val recipeViewModel: RecipeViewModel = viewModel(factory = RecipeViewModel.factory(container))
    MealPlanScreen(
        mealPlanViewModel = mealPlanViewModel,
        recipeViewModel = recipeViewModel,
        onOpenRecipe = {},
    )
}

/** Port of ios/Sources/MealieUI/Views/MealPlanTab/MealPlanView.swift. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MealPlanScreen(
    mealPlanViewModel: MealPlanViewModel,
    recipeViewModel: RecipeViewModel,
    onOpenRecipe: (String) -> Unit,
) {
    val state by mealPlanViewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    var isRefreshing by remember { mutableStateOf(false) }
    var addSheetDate by remember { mutableStateOf<LocalDate?>(null) }
    var errorDismissed by remember(state.errorMessage, state.errorDetail) { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        mealPlanViewModel.loadWeek()
    }

    val today = LocalDate.now()
    val weekFormatter = remember { DateTimeFormatter.ofPattern("MMM d", Locale.getDefault()) }
    val weekTitle = "${state.currentWeekStart.format(weekFormatter)} - " +
        state.currentWeekStart.plusDays(6).format(weekFormatter)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Meal Plan") },
                actions = {
                    TextButton(
                        onClick = {
                            mealPlanViewModel.goToThisWeek()
                            scope.launch { mealPlanViewModel.loadWeek() }
                        },
                    ) {
                        Text("Today")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (state.errorMessage.isNotEmpty() && !errorDismissed) {
                MealPlanErrorBanner(
                    message = state.errorMessage,
                    detail = state.errorDetail,
                    onDismiss = { errorDismissed = true },
                )
            }

            // Week navigation header
            Surface(color = MaterialTheme.colorScheme.surfaceVariant) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(
                        onClick = {
                            mealPlanViewModel.previousWeek()
                            scope.launch { mealPlanViewModel.loadWeek() }
                        },
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                            contentDescription = "Previous week",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                    Text(
                        text = weekTitle,
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.weight(1f),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    IconButton(
                        onClick = {
                            mealPlanViewModel.nextWeek()
                            scope.launch { mealPlanViewModel.loadWeek() }
                        },
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = "Next week",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    scope.launch {
                        isRefreshing = true
                        mealPlanViewModel.loadWeek()
                        isRefreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    items(state.weekDates, key = { MealPlanViewModel.dateString(it) }) { date ->
                        DaySection(
                            date = date,
                            entries = state.weekEntries[MealPlanViewModel.dateString(date)].orEmpty(),
                            isToday = date == today,
                            onAdd = { addSheetDate = date },
                            onOpenRecipe = onOpenRecipe,
                            onDelete = { id -> scope.launch { mealPlanViewModel.deleteMealPlan(id) } },
                        )
                    }
                }
            }
        }
    }

    addSheetDate?.let { date ->
        AddMealPlanSheet(
            date = date,
            mealPlanViewModel = mealPlanViewModel,
            recipeViewModel = recipeViewModel,
            onDismiss = { addSheetDate = null },
        )
    }
}

@Composable
private fun DaySection(
    date: LocalDate,
    entries: List<MealPlanEntry>,
    isToday: Boolean,
    onAdd: () -> Unit,
    onOpenRecipe: (String) -> Unit,
    onDelete: (Int) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = MealPlanViewModel.dayName(date),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = MealPlanViewModel.dayNumber(date),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = if (isToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                )
            }
            IconButton(onClick = onAdd) {
                Icon(
                    Icons.Outlined.AddCircleOutline,
                    contentDescription = "Add meal",
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }

        if (entries.isEmpty()) {
            Text(
                text = "No meals planned",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 4.dp),
            )
        } else {
            entries.forEach { entry ->
                MealEntryRow(
                    entry = entry,
                    onOpenRecipe = onOpenRecipe,
                    onDelete = onDelete,
                )
            }
        }

        HorizontalDivider()
    }
}

@Composable
private fun MealEntryRow(
    entry: MealPlanEntry,
    onOpenRecipe: (String) -> Unit,
    onDelete: (Int) -> Unit,
) {
    val recipeSlug = entry.recipe?.slug
    val navigable = recipeSlug != null

    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .then(
                    if (navigable) Modifier.clickable { recipeSlug?.let(onOpenRecipe) } else Modifier
                )
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = mealTypeIcon(entry.mealType),
                contentDescription = entry.mealType.displayName,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp),
            )
            Column(modifier = Modifier.weight(1f).padding(vertical = 4.dp)) {
                Text(
                    text = entry.mealType.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = entry.displayTitle,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (navigable) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp),
                )
            }
            IconButton(
                onClick = { entry.id?.let(onDelete) },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Delete meal",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

private fun mealTypeIcon(type: MealType): ImageVector = when (type) {
    MealType.BREAKFAST -> Icons.Default.WbTwilight
    MealType.LUNCH -> Icons.Default.WbSunny
    MealType.DINNER -> Icons.Default.DarkMode
    MealType.SNACK -> Icons.Default.EmojiFoodBeverage
}

/** Port of the Swift AddMealPlanView sheet. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddMealPlanSheet(
    date: LocalDate,
    mealPlanViewModel: MealPlanViewModel,
    recipeViewModel: RecipeViewModel,
    onDismiss: () -> Unit,
) {
    val recipeState by recipeViewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var selectedMealType by remember { mutableStateOf(MealType.DINNER) }
    var searchText by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        if (recipeState.recipes.isEmpty()) {
            recipeViewModel.loadRecipes(reset = true)
        }
    }

    val displayedRecipes = remember(recipeState.recipes, searchText) {
        if (searchText.isBlank()) {
            recipeState.recipes
        } else {
            val query = searchText.lowercase()
            recipeState.recipes.filter { it.name?.lowercase()?.contains(query) == true }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                text = "Add Meal - ${MealPlanViewModel.dayName(date)}",
                style = MaterialTheme.typography.titleLarge,
            )

            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                MealType.entries.forEachIndexed { index, type ->
                    SegmentedButton(
                        selected = selectedMealType == type,
                        onClick = { selectedMealType = type },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = MealType.entries.size),
                    ) {
                        Text(type.displayName, maxLines = 1)
                    }
                }
            }

            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = { Text("Search recipes...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                keyboardActions = KeyboardActions.Default,
                modifier = Modifier.fillMaxWidth(),
            )

            LazyColumn(
                modifier = Modifier.fillMaxWidth().weight(1f, fill = false),
            ) {
                items(displayedRecipes, key = { it.id ?: it.slug ?: it.name.orEmpty() }) { recipe ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                val recipeId = recipe.id
                                scope.launch {
                                    if (recipeId != null) {
                                        mealPlanViewModel.addMealPlan(date, selectedMealType, recipeId)
                                    }
                                    onDismiss()
                                }
                            }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = recipe.name ?: "Untitled",
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Icon(
                            Icons.Default.AddCircle,
                            contentDescription = "Add",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                    HorizontalDivider()
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/** Red dismissible error banner matching the iOS ErrorBanner (docs/UI_SPECS.md). */
@Composable
private fun MealPlanErrorBanner(
    message: String,
    detail: String,
    onDismiss: () -> Unit,
) {
    var showDetail by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .background(
                color = androidx.compose.ui.graphics.Color.Red.copy(alpha = 0.9f),
                shape = RoundedCornerShape(10.dp),
            )
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Default.Warning,
                contentDescription = null,
                tint = androidx.compose.ui.graphics.Color.White,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = androidx.compose.ui.graphics.Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (detail.isNotEmpty()) {
                IconButton(onClick = { showDetail = !showDetail }, modifier = Modifier.size(24.dp)) {
                    Icon(
                        if (showDetail) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                        contentDescription = "Toggle details",
                        tint = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f),
                    )
                }
            }
            IconButton(onClick = onDismiss, modifier = Modifier.size(24.dp)) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint = androidx.compose.ui.graphics.Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        if (detail.isNotEmpty() && showDetail) {
            Text(
                text = detail,
                style = MaterialTheme.typography.bodySmall,
                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
