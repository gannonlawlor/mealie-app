package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.jackabee.mealie.data.model.RecipeSummary

/**
 * A recipe list row: 60dp rounded thumbnail, name, 2-line description, up to
 * 3 category chips, offline badge and star rating. Long press opens a context
 * menu with Favorite, Save Offline (server mode) and Delete actions.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun RecipeRow(
    recipe: RecipeSummary,
    imageModel: Any?,
    isSavedOffline: Boolean,
    isFavorite: Boolean,
    isSelected: Boolean,
    showOfflineAction: Boolean,
    onClick: () -> Unit,
    onToggleFavorite: () -> Unit,
    onToggleOffline: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menuExpanded by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                else Color.Transparent
            )
            .combinedClickable(
                onClick = onClick,
                onLongClick = { menuExpanded = true },
            )
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (recipe.id != null) {
                if (imageModel != null) {
                    AsyncImage(
                        model = imageModel,
                        contentDescription = recipe.name,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(60.dp)
                            .clip(RoundedCornerShape(8.dp)),
                    )
                } else {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(60.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Image,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Spacer(modifier = Modifier.width(12.dp))
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = recipe.name ?: "Untitled",
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                val description = recipe.description
                if (!description.isNullOrEmpty()) {
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                val categories = recipe.recipeCategory.orEmpty()
                if (categories.isNotEmpty()) {
                    Row(modifier = Modifier.padding(top = 4.dp)) {
                        categories.take(3).forEach { category ->
                            Text(
                                text = category.name ?: "",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier
                                    .padding(end = 4.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f))
                                    .padding(horizontal = 6.dp, vertical = 2.dp),
                            )
                        }
                    }
                }
            }

            if (isSavedOffline) {
                Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = "Saved offline",
                    tint = Color(0xFF4CAF50),
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .size(16.dp),
                )
            }

            val rating = recipe.rating
            if (rating != null && rating > 0) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(start = 8.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Star,
                        contentDescription = null,
                        tint = Color(0xFFFFA000),
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = "$rating",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 2.dp),
                    )
                }
            }
        }

        DropdownMenu(
            expanded = menuExpanded,
            onDismissRequest = { menuExpanded = false },
        ) {
            DropdownMenuItem(
                text = { Text(if (isFavorite) "Unfavorite" else "Favorite") },
                onClick = {
                    menuExpanded = false
                    onToggleFavorite()
                },
            )
            if (showOfflineAction) {
                DropdownMenuItem(
                    text = { Text(if (isSavedOffline) "Remove Offline" else "Save Offline") },
                    onClick = {
                        menuExpanded = false
                        onToggleOffline()
                    },
                )
            }
            DropdownMenuItem(
                text = { Text("Delete", color = MaterialTheme.colorScheme.error) },
                onClick = {
                    menuExpanded = false
                    onDelete()
                },
            )
        }
    }
}
