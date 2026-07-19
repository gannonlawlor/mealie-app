package com.jackabee.mealie.ui.screens.shopping

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.launch

/**
 * Shopping lists feature entry point.
 *
 * Compact: full-screen list of shopping lists (port of ShoppingListsView.swift);
 * tapping a row calls [onOpenList]. Wide: two-pane layout (port of
 * ShoppingSplitView.swift) with a 340dp list pane and an inline detail pane.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShoppingPane(
    shoppingViewModel: ShoppingViewModel,
    isWideLayout: Boolean,
    onOpenList: (String) -> Unit,
) {
    val state by shoppingViewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    var isRefreshing by remember { mutableStateOf(false) }
    var showNewListDialog by remember { mutableStateOf(false) }
    var selectedListId by remember { mutableStateOf<String?>(null) }
    var errorDismissed by remember(state.errorMessage, state.errorDetail) { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (shoppingViewModel.uiState.value.shoppingLists.isEmpty()) {
            shoppingViewModel.loadShoppingLists()
        }
    }

    val onDeleteList: (String) -> Unit = { id ->
        if (selectedListId == id) selectedListId = null
        scope.launch { shoppingViewModel.deleteShoppingList(id) }
    }

    val listContent: @Composable () -> Unit = {
        Column(modifier = Modifier.fillMaxSize()) {
            if (state.errorMessage.isNotEmpty() && !errorDismissed) {
                ShoppingErrorBanner(
                    message = state.errorMessage,
                    detail = state.errorDetail,
                    onDismiss = { errorDismissed = true },
                )
            }
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    scope.launch {
                        isRefreshing = true
                        shoppingViewModel.loadShoppingLists()
                        isRefreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.isLoading && state.shoppingLists.isEmpty() -> {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    }
                    state.shoppingLists.isEmpty() -> {
                        // Inside a scrollable container so pull-to-refresh still works.
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            item {
                                Text(
                                    text = "No shopping lists yet",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(16.dp),
                                )
                            }
                        }
                    }
                    else -> {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            items(state.shoppingLists, key = { it.id.orEmpty() }) { list ->
                                ShoppingListRow(
                                    list = list,
                                    selected = isWideLayout && selectedListId == list.id,
                                    onClick = {
                                        val id = list.id ?: return@ShoppingListRow
                                        if (isWideLayout) selectedListId = id else onOpenList(id)
                                    },
                                    onDelete = { list.id?.let(onDeleteList) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (isWideLayout) {
        Row(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.width(340.dp).fillMaxHeight()) {
                TopAppBar(
                    title = { Text("Shopping Lists") },
                    actions = {
                        IconButton(onClick = { showNewListDialog = true }) {
                            Icon(Icons.Default.Add, contentDescription = "New shopping list")
                        }
                    },
                )
                listContent()
            }
            VerticalDivider()
            Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
                val listId = selectedListId
                if (listId != null) {
                    key(listId) {
                        ShoppingListDetailContent(
                            listId = listId,
                            shoppingViewModel = shoppingViewModel,
                            onBack = null,
                        )
                    }
                } else {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            Icons.Default.ShoppingCart,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(48.dp),
                        )
                        Text(
                            text = "Select a shopping list",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Shopping Lists") },
                    actions = {
                        IconButton(onClick = { showNewListDialog = true }) {
                            Icon(Icons.Default.Add, contentDescription = "New shopping list")
                        }
                    },
                )
            },
        ) { padding ->
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                listContent()
            }
        }
    }

    if (showNewListDialog) {
        NewShoppingListDialog(
            onDismiss = { showNewListDialog = false },
            onCreate = { name ->
                showNewListDialog = false
                scope.launch { shoppingViewModel.createShoppingList(name) }
            },
        )
    }
}

/** Row for a shopping list with swipe-to-dismiss delete. */
@Composable
private fun ShoppingListRow(
    list: ShoppingList,
    selected: Boolean,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else {
                false
            }
        },
    )

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.errorContainer)
                    .padding(horizontal = 20.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete list",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                    else MaterialTheme.colorScheme.surface
                )
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = list.name ?: "Untitled",
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "${list.uncheckedCount} items remaining",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (list.checkedCount > 0) {
                Text(
                    text = "${list.checkedCount} done",
                    style = MaterialTheme.typography.labelSmall,
                    color = ShoppingGreen,
                    modifier = Modifier
                        .background(ShoppingGreen.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                )
            }
        }
    }
}

/** "New Shopping List" dialog shared by compact and wide layouts. */
@Composable
private fun NewShoppingListDialog(
    onDismiss: () -> Unit,
    onCreate: (String) -> Unit,
) {
    var name by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New Shopping List") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Enter a name for the new shopping list.")
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = { Text("List name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onCreate(name) }, enabled = name.isNotBlank()) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
    )
}

/** Green used for check/done accents, matching the iOS system green usage. */
internal val ShoppingGreen = Color(0xFF34A853)

/** Red dismissible error banner matching the iOS ErrorBanner (docs/UI_SPECS.md). */
@Composable
internal fun ShoppingErrorBanner(
    message: String,
    detail: String,
    onDismiss: () -> Unit,
) {
    var showDetail by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .background(Color.Red.copy(alpha = 0.9f), RoundedCornerShape(10.dp))
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Default.Warning, contentDescription = null, tint = Color.White)
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (detail.isNotEmpty()) {
                IconButton(onClick = { showDetail = !showDetail }, modifier = Modifier.size(24.dp)) {
                    Icon(
                        if (showDetail) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                        contentDescription = "Toggle details",
                        tint = Color.White.copy(alpha = 0.8f),
                    )
                }
            }
            IconButton(onClick = onDismiss, modifier = Modifier.size(24.dp)) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        if (detail.isNotEmpty() && showDetail) {
            Text(
                text = detail,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.85f),
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}
