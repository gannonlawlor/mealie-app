package com.jackabee.mealie.ui.screens.recipes.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.ui.viewmodel.RecipeUiState
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import kotlinx.coroutines.launch

/**
 * Import-recipe bottom sheet: URL field + "Import Recipe" button + status
 * message. In local mode it additionally offers a "Create New Recipe" flow.
 * Closes itself automatically after a successful import (unless the duplicate
 * alert is showing).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportRecipeSheet(
    recipeViewModel: RecipeViewModel,
    state: RecipeUiState,
    onDismiss: () -> Unit,
    onRecipeCreated: (Recipe) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var showCreateForm by rememberSaveable { mutableStateOf(false) }
    var newRecipeName by rememberSaveable { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = "Import a Recipe",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) {
                    Text("Cancel")
                }
            }

            Text(
                text = if (state.isLocalMode) {
                    "Paste a URL and the recipe will be parsed and saved locally."
                } else {
                    "Paste a URL from a recipe website and Mealie will automatically import it."
                },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            OutlinedTextField(
                value = state.importURL,
                onValueChange = { recipeViewModel.updateImportURL(it) },
                placeholder = { Text("Recipe URL") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            Button(
                onClick = {
                    scope.launch {
                        recipeViewModel.importFromURL()
                        val newState = recipeViewModel.uiState.value
                        if (newState.importMessage.contains("successfully") && !newState.showDuplicateAlert) {
                            onDismiss()
                        }
                    }
                },
                enabled = state.importURL.isNotEmpty() && !state.isImporting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.isImporting) {
                    CircularProgressIndicator(
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    Text("Import Recipe")
                }
            }

            if (state.importMessage.isNotEmpty()) {
                Text(
                    text = state.importMessage,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (state.importMessage.contains("successfully")) {
                        Color(0xFF4CAF50)
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                    textAlign = TextAlign.Center,
                )
            }

            if (state.isLocalMode) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    HorizontalDivider(modifier = Modifier.weight(1f))
                    Text(
                        text = "or",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 8.dp),
                    )
                    HorizontalDivider(modifier = Modifier.weight(1f))
                }

                if (showCreateForm) {
                    OutlinedTextField(
                        value = newRecipeName,
                        onValueChange = { newRecipeName = it },
                        placeholder = { Text("Recipe Name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Button(
                        onClick = {
                            scope.launch {
                                val recipe = recipeViewModel.createLocalRecipe(newRecipeName)
                                onRecipeCreated(recipe)
                            }
                        },
                        enabled = newRecipeName.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Create Recipe")
                    }
                } else {
                    OutlinedButton(
                        onClick = { showCreateForm = true },
                        border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.AddCircleOutline,
                            contentDescription = null,
                            modifier = Modifier
                                .padding(end = 8.dp)
                                .size(18.dp),
                        )
                        Text("Create New Recipe")
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/**
 * "Recipe Already Exists" alert with the exact iOS message variants and
 * Update Existing / Import Anyway / Cancel actions.
 */
@Composable
fun DuplicateRecipeDialog(
    recipeViewModel: RecipeViewModel,
    state: RecipeUiState,
    onResolved: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val name = state.duplicateRecipe?.name ?: ""
    val message = if (state.duplicateMatchedByURL) {
        "A recipe imported from this URL already exists: \"$name\". Would you like to update it or import a new copy?"
    } else {
        "A recipe with the same name already exists: \"$name\". Would you like to update it or import a new copy?"
    }

    androidx.compose.material3.AlertDialog(
        onDismissRequest = { recipeViewModel.clearDuplicateState() },
        title = { Text("Recipe Already Exists") },
        text = { Text(message) },
        confirmButton = {
            Column(horizontalAlignment = Alignment.End) {
                TextButton(onClick = {
                    scope.launch {
                        recipeViewModel.confirmImportUpdate()
                        onResolved()
                    }
                }) {
                    Text("Update Existing")
                }
                TextButton(onClick = {
                    scope.launch {
                        recipeViewModel.confirmImportNew()
                        onResolved()
                    }
                }) {
                    Text("Import Anyway")
                }
                TextButton(onClick = { recipeViewModel.clearDuplicateState() }) {
                    Text("Cancel")
                }
            }
        },
    )
}
