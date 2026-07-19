package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.data.model.MealType
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * "Add to Meal Plan" bottom sheet: segmented meal-type row (default Dinner)
 * plus rows for today through +6 days. Tapping a day adds the meal plan
 * entry and closes the sheet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddToMealPlanSheet(
    mealPlanViewModel: MealPlanViewModel,
    recipeId: String,
    onDismiss: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var selectedMealType by remember { mutableStateOf(MealType.DINNER) }
    var isAdding by remember { mutableStateOf(false) }
    val today = remember { LocalDate.now() }
    val dates = remember(today) { (0L..6L).map { today.plusDays(it) } }

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
                    text = "Add to Meal Plan",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) {
                    Text("Cancel")
                }
            }

            SingleChoiceSegmentedButtonRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
            ) {
                MealType.entries.forEachIndexed { index, type ->
                    SegmentedButton(
                        selected = selectedMealType == type,
                        onClick = { selectedMealType = type },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = MealType.entries.size),
                    ) {
                        Text(type.displayName)
                    }
                }
            }

            dates.forEach { date ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = !isAdding) {
                            if (!isAdding) {
                                isAdding = true
                                scope.launch {
                                    mealPlanViewModel.addMealPlan(date, selectedMealType, recipeId)
                                    isAdding = false
                                    onDismiss()
                                }
                            }
                        }
                        .padding(vertical = 12.dp, horizontal = 4.dp),
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = dayLabel(date, today),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Text(
                            text = date.format(DateTimeFormatter.ofPattern("MMM d", Locale.getDefault())),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Icon(
                        imageVector = Icons.Outlined.AddCircleOutline,
                        contentDescription = "Add",
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}

private fun dayLabel(date: LocalDate, today: LocalDate): String = when (date) {
    today -> "Today"
    today.plusDays(1) -> "Tomorrow"
    else -> date.format(DateTimeFormatter.ofPattern("EEEE", Locale.getDefault()))
}
