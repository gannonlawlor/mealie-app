package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.data.model.ShoppingList

/**
 * "Add to Shopping List" picker sheet shown when no default shopping list is
 * configured. Rows show the list name with a "{n} pending" caption when the
 * local queue has items for that list.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShoppingListPickerSheet(
    shoppingLists: List<ShoppingList>,
    pendingItemCounts: Map<String, Int>,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Add to Shopping List",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) {
                    Text("Cancel")
                }
            }

            if (shoppingLists.isEmpty()) {
                Text(
                    text = "No shopping lists found",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 16.dp),
                )
            } else {
                shoppingLists.forEach { list ->
                    val listId = list.id ?: return@forEach
                    val pending = pendingItemCounts[listId] ?: 0
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onPick(listId) }
                            .padding(vertical = 14.dp, horizontal = 4.dp),
                    ) {
                        Text(
                            text = list.name ?: "Untitled",
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f),
                        )
                        if (pending > 0) {
                            Text(
                                text = "$pending pending",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}
