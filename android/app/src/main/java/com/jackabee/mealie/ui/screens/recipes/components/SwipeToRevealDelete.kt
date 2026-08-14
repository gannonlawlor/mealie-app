package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Width of the revealed action button. */
private val ActionWidth = 88.dp

/** Fling speed (px/s) that opens or closes regardless of how far the row moved. */
private const val FlingVelocity = 400f

/**
 * Wraps a list row so that swiping it left slides it aside and reveals a
 * Delete button, which must be tapped to actually delete (a swipe alone never
 * deletes). Swiping back — or a tap handled by the caller — closes it again.
 *
 * The open/closed state is hoisted via [isRevealed]/[onRevealChange] so the
 * list can keep at most one row open at a time.
 */
@Composable
fun SwipeToRevealDelete(
    isRevealed: Boolean,
    onRevealChange: (Boolean) -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val actionWidthPx = with(LocalDensity.current) { ActionWidth.toPx() }
    val offsetX = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    // Follow state changes driven from outside (another row opening, a tap
    // closing this one). Drag-initiated changes animate in onDragStopped.
    LaunchedEffect(isRevealed, actionWidthPx) {
        offsetX.animateTo(if (isRevealed) -actionWidthPx else 0f)
    }

    val dragState = rememberDraggableState { delta ->
        scope.launch {
            offsetX.snapTo((offsetX.value + delta).coerceIn(-actionWidthPx, 0f))
        }
    }

    // Only compose the action while the row is off its resting position, so a
    // closed row has no hidden button behind it for accessibility services.
    // derivedStateOf keeps this from recomposing on every frame of the drag.
    val actionVisible by remember { derivedStateOf { offsetX.value != 0f } }

    Box(modifier = modifier.fillMaxWidth()) {
        if (actionVisible) {
            Row(
                horizontalArrangement = Arrangement.End,
                modifier = Modifier.matchParentSize(),
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(ActionWidth)
                        .background(MaterialTheme.colorScheme.error)
                        .clickable(onClick = onDelete),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Delete,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onError,
                    )
                    Text(
                        text = "Delete",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onError,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }

        Box(
            modifier = Modifier
                .offset { IntOffset(offsetX.value.roundToInt(), 0) }
                .background(MaterialTheme.colorScheme.surface)
                .draggable(
                    state = dragState,
                    orientation = Orientation.Horizontal,
                    onDragStopped = { velocity ->
                        val reveal = when {
                            velocity <= -FlingVelocity -> true
                            velocity >= FlingVelocity -> false
                            else -> offsetX.value <= -actionWidthPx / 2f
                        }
                        onRevealChange(reveal)
                        offsetX.animateTo(if (reveal) -actionWidthPx else 0f)
                    },
                ),
        ) {
            content()
        }
    }
}
