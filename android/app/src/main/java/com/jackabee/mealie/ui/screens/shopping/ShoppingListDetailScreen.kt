package com.jackabee.mealie.ui.screens.shopping

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.launch

/** Port of ios/Sources/MealieUI/Views/ShoppingTab/ShoppingListDetailView.swift. */
@Composable
fun ShoppingListDetailScreen(
    listId: String,
    shoppingViewModel: ShoppingViewModel,
    onBack: () -> Unit,
) {
    ShoppingListDetailContent(
        listId = listId,
        shoppingViewModel = shoppingViewModel,
        onBack = onBack,
    )
}

/**
 * Shared detail body. [onBack] null means embedded in the wide two-pane layout,
 * where no back navigation icon is shown.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ShoppingListDetailContent(
    listId: String,
    shoppingViewModel: ShoppingViewModel,
    onBack: (() -> Unit)?,
) {
    val state by shoppingViewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val groceryStore = (LocalContext.current.applicationContext as MealieApplication)
        .container.localGroceryStore

    var isRefreshing by remember { mutableStateOf(false) }
    var errorDismissed by remember(state.errorMessage, state.errorDetail) { mutableStateOf(false) }
    var syncBannerDismissed by remember(state.syncMessage) { mutableStateOf(false) }
    var pendingItems by remember(listId) { mutableStateOf(groceryStore.pendingItems(listId)) }

    LaunchedEffect(listId) {
        shoppingViewModel.refreshPendingCounts()
        shoppingViewModel.loadShoppingList(listId)
    }

    // Keep the local pending list in sync whenever the VM's counts change
    // (after sync, deletes, or items queued from the recipe detail screen).
    LaunchedEffect(state.pendingItemCounts) {
        pendingItems = groceryStore.pendingItems(listId)
    }

    val listItems = state.selectedList?.listItems.orEmpty()
    val uncheckedItems = listItems.filter { it.checked != true }
    val checkedItems = listItems.filter { it.checked == true }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.selectedList?.name ?: "Shopping List",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    if (onBack != null) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    if (pendingItems.isNotEmpty()) {
                        if (state.isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.padding(end = 16.dp).size(24.dp),
                                strokeWidth = 2.dp,
                            )
                        } else {
                            IconButton(
                                onClick = { scope.launch { shoppingViewModel.syncPendingItems(listId) } },
                            ) {
                                Icon(Icons.Default.ArrowUpward, contentDescription = "Upload pending items")
                            }
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (state.errorMessage.isNotEmpty() && !errorDismissed) {
                ShoppingErrorBanner(
                    message = state.errorMessage,
                    detail = state.errorDetail,
                    onDismiss = { errorDismissed = true },
                )
            }

            if (state.syncMessage.isNotEmpty() && !syncBannerDismissed) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(ShoppingGreen.copy(alpha = 0.1f))
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = ShoppingGreen,
                    )
                    Text(
                        text = state.syncMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(
                        onClick = { syncBannerDismissed = true },
                        modifier = Modifier.size(24.dp),
                    ) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }
            }

            // Add item bar
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = state.newItemNote,
                    onValueChange = shoppingViewModel::updateNewItemNote,
                    placeholder = { Text("Add an item...") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                FilledIconButton(
                    onClick = { scope.launch { shoppingViewModel.addItem(listId) } },
                    enabled = state.newItemNote.isNotBlank(),
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Add item")
                }
            }

            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    scope.launch {
                        isRefreshing = true
                        shoppingViewModel.refreshPendingCounts()
                        shoppingViewModel.loadShoppingList(listId)
                        isRefreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                if (state.isLoading && state.selectedList == null) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        if (pendingItems.isNotEmpty()) {
                            item(key = "header-pending") { SectionHeader("Pending Upload") }
                            itemsIndexed(pendingItems, key = { _, item -> "pending-${item.id}" }) { index, item ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 16.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Icon(
                                        Icons.Default.ArrowUpward,
                                        contentDescription = null,
                                        tint = PendingOrange,
                                    )
                                    Text(
                                        text = item.note,
                                        modifier = Modifier.weight(1f),
                                    )
                                    IconButton(
                                        onClick = {
                                            groceryStore.removePendingItem(index, listId)
                                            shoppingViewModel.refreshPendingCounts()
                                        },
                                        modifier = Modifier.size(32.dp),
                                    ) {
                                        Icon(
                                            Icons.Default.Delete,
                                            contentDescription = "Remove pending item",
                                            tint = MaterialTheme.colorScheme.error,
                                            modifier = Modifier.size(18.dp),
                                        )
                                    }
                                }
                            }
                            item(key = "upload-button") {
                                TextButton(
                                    onClick = { scope.launch { shoppingViewModel.syncPendingItems(listId) } },
                                    enabled = !state.isSyncing,
                                    modifier = Modifier.padding(horizontal = 8.dp),
                                ) {
                                    if (state.isSyncing) {
                                        CircularProgressIndicator(
                                            modifier = Modifier.padding(end = 8.dp).size(16.dp),
                                            strokeWidth = 2.dp,
                                        )
                                    } else {
                                        Icon(
                                            Icons.Default.ArrowUpward,
                                            contentDescription = null,
                                            modifier = Modifier.padding(end = 8.dp).size(18.dp),
                                        )
                                    }
                                    Text(
                                        if (state.isSyncing) "Uploading..."
                                        else "Upload ${pendingItems.size} items"
                                    )
                                }
                            }
                        }

                        if (uncheckedItems.isNotEmpty()) {
                            item(key = "header-tobuy") { SectionHeader("To Buy") }
                            items(uncheckedItems, key = { "item-${it.id}" }) { item ->
                                ShoppingItemRow(
                                    item = item,
                                    onToggle = { scope.launch { shoppingViewModel.toggleItem(item) } },
                                    onDelete = { scope.launch { shoppingViewModel.deleteItem(item) } },
                                )
                            }
                        }

                        if (checkedItems.isNotEmpty()) {
                            item(key = "header-completed") { SectionHeader("Completed") }
                            items(checkedItems, key = { "item-${it.id}" }) { item ->
                                ShoppingItemRow(
                                    item = item,
                                    onToggle = { scope.launch { shoppingViewModel.toggleItem(item) } },
                                    onDelete = { scope.launch { shoppingViewModel.deleteItem(item) } },
                                )
                            }
                        }

                        if (pendingItems.isEmpty() && uncheckedItems.isEmpty() && checkedItems.isEmpty()) {
                            item(key = "empty") {
                                Text(
                                    text = "No items in this list",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(16.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 4.dp),
    )
}

@Composable
private fun ShoppingItemRow(
    item: ShoppingListItem,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
) {
    val checked = item.checked == true

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = if (checked) Icons.Default.CheckCircle else Icons.Outlined.Circle,
            contentDescription = if (checked) "Checked" else "Unchecked",
            tint = if (checked) ShoppingGreen else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = item.displayText,
                textDecoration = if (checked) TextDecoration.LineThrough else null,
                color = if (checked) MaterialTheme.colorScheme.onSurfaceVariant
                else MaterialTheme.colorScheme.onSurface,
            )
            val note = item.note
            if (!note.isNullOrEmpty() && item.food != null) {
                Text(
                    text = note,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete item",
                tint = MaterialTheme.colorScheme.error,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** Orange used for the pending-upload accents, matching the iOS system orange. */
private val PendingOrange = Color(0xFFFF9500)
