package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.gestures.detectTapGestures
import com.jackabee.mealie.data.model.RecipeIngredient

/**
 * A bulleted ingredient row. In server mode, pressing and holding fills the
 * row background with 15% accent from left to right over 500ms; when the long
 * press triggers, [onLongPressComplete] fires (add-to-shopping-list).
 */
@Composable
fun IngredientRow(
    ingredient: RecipeIngredient,
    longPressEnabled: Boolean,
    onLongPressComplete: (RecipeIngredient) -> Unit,
    modifier: Modifier = Modifier,
) {
    var pressed by remember { mutableStateOf(false) }
    val fillFraction by animateFloatAsState(
        targetValue = if (pressed) 1f else 0f,
        animationSpec = if (pressed) {
            tween(durationMillis = 500, easing = LinearEasing)
        } else {
            tween(durationMillis = 200, easing = FastOutSlowInEasing)
        },
        label = "ingredientLongPressFill",
    )
    val fillColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)

    Row(
        verticalAlignment = Alignment.Top,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .drawBehind {
                if (fillFraction > 0f) {
                    drawRect(
                        color = fillColor,
                        size = Size(size.width * fillFraction, size.height),
                    )
                }
            }
            .pointerInput(longPressEnabled) {
                if (longPressEnabled) {
                    detectTapGestures(
                        onPress = {
                            pressed = true
                            tryAwaitRelease()
                            pressed = false
                        },
                        onLongPress = {
                            pressed = false
                            onLongPressComplete(ingredient)
                        },
                    )
                }
            }
            .padding(horizontal = 8.dp, vertical = 6.dp),
    ) {
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .size(6.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.onSurfaceVariant),
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = ingredient.displayText,
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}
