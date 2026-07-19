package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.di.AppContainer
import java.io.File

/** Resolves the app's manual DI container from the current context. */
@Composable
fun rememberAppContainer(): AppContainer {
    val context = LocalContext.current
    return remember(context) {
        (context.applicationContext as MealieApplication).container
    }
}

/** Mirrors the iOS `formatDuration`: "PT1H30M" -> "1h 30m"; non-ISO strings pass through. */
fun formatDuration(iso: String): String {
    var result = iso
        .replace("PT", "")
        .replace("H", "h ")
        .replace("M", "m ")
        .replace("S", "s")
        .trim()
    if (!result.contains("h") && !result.contains("m") && !result.contains("s")) {
        result = iso // If not ISO format, return as-is
    }
    return result
}

/**
 * Coil model for a recipe list thumbnail. Local mode uses the locally stored
 * image file; server mode falls back to the tiny image endpoint.
 */
fun thumbnailImageModel(container: AppContainer, isLocalMode: Boolean, recipeId: String): Any? {
    if (isLocalMode) {
        return container.localRecipeStore.imageFilePath(recipeId)?.let { File(it) }
    }
    return container.api.recipeImageURL(recipeId, "tiny-original.webp")
}

/**
 * Coil model for the recipe detail hero image. Resolution order:
 * local file path -> offline file path -> network min-original.webp.
 */
fun heroImageModel(container: AppContainer, isLocalMode: Boolean, recipeId: String): Any? {
    if (isLocalMode) {
        return container.localRecipeStore.imageFilePath(recipeId)?.let { File(it) }
    }
    container.offlineRecipeStore.imageFilePath(recipeId)?.let { return File(it) }
    return container.api.recipeImageURL(recipeId)
}

/** Red dismissible error card with an expandable detail section. */
@Composable
fun ErrorBanner(
    message: String,
    detail: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xE6C62828))
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Filled.Warning,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(20.dp),
            )
            Text(
                text = message,
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 8.dp),
            )
            if (detail.isNotEmpty()) {
                IconButton(onClick = { expanded = !expanded }) {
                    Icon(
                        imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                        contentDescription = if (expanded) "Hide details" else "Show details",
                        tint = Color.White,
                    )
                }
            }
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Dismiss",
                    tint = Color.White,
                )
            }
        }
        if (expanded && detail.isNotEmpty()) {
            Text(
                text = detail,
                color = Color.White.copy(alpha = 0.85f),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

/**
 * Accent chip used for categories/tags: filled primary when selected,
 * 12% primary fill otherwise (mirrors the iOS accent chips).
 */
@Composable
fun MealieChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: (@Composable () -> Unit)? = null,
) {
    val background = if (selected) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
    }
    val contentColor = if (selected) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.primary
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        if (icon != null) {
            icon()
        }
        Text(
            text = label,
            color = contentColor,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
