package com.jackabee.mealie.ui.screens.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.BuildConfig

/**
 * Shared error banner, per the UI spec: red (90%) rounded card with a warning
 * triangle, white 2-line message, debug-only expandable detail and an x dismiss.
 */
@Composable
fun ErrorBanner(
    message: String,
    detail: String = "",
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (message.isEmpty()) return
    var showDetail by remember { mutableStateOf(false) }
    val showDetailToggle = BuildConfig.DEBUG && detail.isNotEmpty()

    Surface(
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        shape = RoundedCornerShape(10.dp),
        color = Color.Red.copy(alpha = 0.9f),
        contentColor = Color.White,
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.Warning,
                    contentDescription = null,
                    modifier = Modifier.padding(end = 8.dp),
                )
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (showDetailToggle) {
                    IconButton(onClick = { showDetail = !showDetail }) {
                        Icon(
                            imageVector = if (showDetail) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                            contentDescription = if (showDetail) "Hide details" else "Show details",
                        )
                    }
                }
                IconButton(onClick = onDismiss) {
                    Icon(imageVector = Icons.Filled.Close, contentDescription = "Dismiss")
                }
            }
            if (showDetailToggle && showDetail) {
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
