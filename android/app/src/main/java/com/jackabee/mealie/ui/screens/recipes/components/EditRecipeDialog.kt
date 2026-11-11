package com.jackabee.mealie.ui.screens.recipes.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.IngredientDraft
import com.jackabee.mealie.data.model.InstructionDraft
import com.jackabee.mealie.data.model.editedAssociations
import com.jackabee.mealie.ui.screens.common.ErrorBanner
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

private const val TAG = "EditRecipeDialog"

/**
 * Full-screen edit-recipe dialog. Also used by the local-mode "Create New
 * Recipe" flow (which creates an empty recipe first and then opens this
 * editor for it).
 *
 * Save preserves untouched ingredient/step metadata and uploads a picked image afterwards.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditRecipeDialog(
    recipe: Recipe,
    recipeViewModel: RecipeViewModel,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val container = rememberAppContainer()
    val recipeState by recipeViewModel.uiState.collectAsStateWithLifecycle()
    val isLocalMode = recipeState.isLocalMode

    var name by remember { mutableStateOf(recipe.name ?: "") }
    var description by remember { mutableStateOf(recipe.description ?: "") }
    var recipeYield by remember { mutableStateOf(recipe.recipeYield ?: "") }
    var prepTime by remember { mutableStateOf(recipe.prepTime ?: "") }
    var performTime by remember { mutableStateOf(recipe.performTime ?: "") }
    var totalTime by remember { mutableStateOf(recipe.totalTime ?: "") }
    val ingredientTexts = remember {
        SnapshotStateList<IngredientDraft>().apply {
            addAll(recipe.recipeIngredient.orEmpty().map { IngredientDraft(it) })
        }
    }
    val instructionTexts = remember {
        SnapshotStateList<InstructionDraft>().apply {
            addAll(recipe.recipeInstructions.orEmpty().map { InstructionDraft(it) })
        }
    }
    val selectedCategoryIds = remember {
        SnapshotStateList<String>().apply {
            addAll(recipe.recipeCategory.orEmpty().mapNotNull { it.id })
        }
    }
    val selectedTagIds = remember {
        SnapshotStateList<String>().apply {
            addAll(recipe.tags.orEmpty().mapNotNull { it.id })
        }
    }
    var isSaving by remember { mutableStateOf(false) }
    var selectedImageUri by remember { mutableStateOf<Uri?>(null) }
    var selectedImageBytes by remember { mutableStateOf<ByteArray?>(null) }

    var showDiscardConfirmation by remember { mutableStateOf(false) }
    val hasUnsavedChanges = name != recipe.name.orEmpty() || description != recipe.description.orEmpty() ||
        recipeYield != recipe.recipeYield.orEmpty() || prepTime != recipe.prepTime.orEmpty() ||
        performTime != recipe.performTime.orEmpty() || totalTime != recipe.totalTime.orEmpty() ||
        ingredientTexts.map { it.text } != recipe.recipeIngredient.orEmpty().map { it.displayText } ||
        instructionTexts.map { it.text } != recipe.recipeInstructions.orEmpty().map { it.text.orEmpty() } ||
        selectedCategoryIds.toSet() != recipe.recipeCategory.orEmpty().mapNotNull { it.id }.toSet() ||
        selectedTagIds.toSet() != recipe.tags.orEmpty().mapNotNull { it.id }.toSet() || selectedImageBytes != null
    fun requestDismiss() {
        if (isSaving) return
        if (hasUnsavedChanges) showDiscardConfirmation = true else onDismiss()
    }
    if (showDiscardConfirmation) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showDiscardConfirmation = false },
            title = { Text("Discard unsaved changes?") },
            confirmButton = { TextButton(onClick = onDismiss) { Text("Discard Changes") } },
            dismissButton = { TextButton(onClick = { showDiscardConfirmation = false }) { Text("Keep Editing") } },
        )
    }

    val photoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        if (uri != null) {
            scope.launch {
                val bytes = withContext(Dispatchers.IO) { uriToJpegBytes(context, uri) }
                if (bytes != null) {
                    selectedImageUri = uri
                    selectedImageBytes = bytes
                }
            }
        }
    }

    fun save() {
        if (name.isBlank() || isSaving) return
        isSaving = true
        scope.launch {
            try {
                val ingredients = ingredientTexts.mapNotNull { it.value() }
                val instructions = instructionTexts.mapNotNull { it.value() }
                val categories = editedAssociations(recipe.recipeCategory.orEmpty(), recipeState.categories, selectedCategoryIds) { it.id }
                val tags = editedAssociations(recipe.tags.orEmpty(), recipeState.tags, selectedTagIds) { it.id }

                val updated = recipe.copy(
                    name = name,
                    description = description.ifEmpty { null },
                    recipeCategory = categories.takeUnless { it.isEmpty() && recipe.recipeCategory == null },
                    tags = tags.takeUnless { it.isEmpty() && recipe.tags == null },
                    recipeYield = recipeYield.ifEmpty { null },
                    recipeIngredient = ingredients.takeUnless { it.isEmpty() && recipe.recipeIngredient == null },
                    recipeInstructions = instructions.takeUnless { it.isEmpty() && recipe.recipeInstructions == null },
                    totalTime = totalTime.ifEmpty { null },
                    prepTime = prepTime.ifEmpty { null },
                    performTime = performTime.ifEmpty { null },
                )

                val success = recipeViewModel.saveRecipeEdits(recipe.slug.orEmpty(), updated, selectedImageBytes)

                if (success) {
                    onDismiss()
                }
            } finally {
                isSaving = false
            }
        }
    }

    Dialog(
        onDismissRequest = { requestDismiss() },
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Scaffold(
                topBar = {
                    Column {
                        TopAppBar(
                            title = { Text("Edit Recipe") },
                            navigationIcon = {
                                TextButton(onClick = { requestDismiss() }, enabled = !isSaving) {
                                    Text("Cancel")
                                }
                            },
                            actions = {
                                if (isSaving) {
                                    CircularProgressIndicator(
                                        strokeWidth = 2.dp,
                                        modifier = Modifier
                                            .padding(end = 16.dp)
                                            .size(20.dp),
                                    )
                                } else {
                                    TextButton(
                                        onClick = { save() },
                                        enabled = name.isNotBlank(),
                                    ) {
                                        Text("Save")
                                    }
                                }
                            },
                        )
                        ErrorBanner(
                            message = recipeState.errorMessage,
                            detail = recipeState.errorDetail,
                            onDismiss = { recipeViewModel.dismissError() },
                        )
                    }
                },
            ) { padding ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .padding(padding)
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                ) {
                    // Image
                    SectionTitle("Image")
                    val imageModel: Any? = selectedImageUri
                        ?: recipe.id?.let { heroImageModel(container, isLocalMode, it) }
                    if (imageModel != null) {
                        AsyncImage(
                            model = imageModel,
                            contentDescription = "Recipe image",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(150.dp)
                                .clip(RoundedCornerShape(8.dp)),
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Outlined.Image,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .align(Alignment.CenterHorizontally)
                                .size(48.dp),
                        )
                    }
                    TextButton(onClick = {
                        photoPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    }) {
                        Icon(
                            imageVector = Icons.Outlined.PhotoLibrary,
                            contentDescription = null,
                            modifier = Modifier
                                .padding(end = 8.dp)
                                .size(18.dp),
                        )
                        Text("Change Image")
                    }

                    // Details
                    SectionTitle("Details")
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("Name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        label = { Text("Description") },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = recipeYield,
                        onValueChange = { recipeYield = it },
                        label = { Text("Yield (e.g. 4 servings)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Times
                    SectionTitle("Times")
                    OutlinedTextField(
                        value = prepTime,
                        onValueChange = { prepTime = it },
                        label = { Text("Prep Time") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = performTime,
                        onValueChange = { performTime = it },
                        label = { Text("Cook Time") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = totalTime,
                        onValueChange = { totalTime = it },
                        label = { Text("Total Time") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Categories
                    val categories = recipeState.categories
                    if (categories.isNotEmpty()) {
                        SectionTitle("Categories")
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                        ) {
                            categories.forEach { category ->
                                val categoryId = category.id ?: return@forEach
                                MealieChip(
                                    label = category.name ?: "",
                                    selected = selectedCategoryIds.contains(categoryId),
                                    onClick = {
                                        if (selectedCategoryIds.contains(categoryId)) {
                                            selectedCategoryIds.remove(categoryId)
                                        } else {
                                            selectedCategoryIds.add(categoryId)
                                        }
                                    },
                                )
                            }
                        }
                    }

                    // Tags
                    val tags = recipeState.tags
                    if (tags.isNotEmpty()) {
                        SectionTitle("Tags")
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                        ) {
                            tags.forEach { tag ->
                                val tagId = tag.id ?: return@forEach
                                MealieChip(
                                    label = tag.name ?: "",
                                    selected = selectedTagIds.contains(tagId),
                                    onClick = {
                                        if (selectedTagIds.contains(tagId)) {
                                            selectedTagIds.remove(tagId)
                                        } else {
                                            selectedTagIds.add(tagId)
                                        }
                                    },
                                )
                            }
                        }
                    }

                    // Ingredients
                    SectionTitle("Ingredients")
                    ingredientTexts.forEachIndexed { index, text ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(
                                value = text.text,
                                onValueChange = { ingredientTexts[index] = text.copy(text = it) },
                                label = { Text("Ingredient") },
                                modifier = Modifier.weight(1f),
                            )
                            IconButton(onClick = { ingredientTexts.removeAt(index) }) {
                                Icon(
                                    imageVector = Icons.Outlined.RemoveCircleOutline,
                                    contentDescription = "Remove ingredient",
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    }
                    TextButton(onClick = { ingredientTexts.add(IngredientDraft()) }) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = null,
                            modifier = Modifier
                                .padding(end = 4.dp)
                                .size(18.dp),
                        )
                        Text("Add Ingredient")
                    }

                    // Instructions
                    SectionTitle("Instructions")
                    instructionTexts.forEachIndexed { index, text ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "${index + 1}.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(end = 8.dp),
                            )
                            OutlinedTextField(
                                value = text.text,
                                onValueChange = { instructionTexts[index] = text.copy(text = it) },
                                label = { Text("Step") },
                                modifier = Modifier.weight(1f),
                            )
                            IconButton(onClick = { instructionTexts.removeAt(index) }) {
                                Icon(
                                    imageVector = Icons.Outlined.RemoveCircleOutline,
                                    contentDescription = "Remove step",
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    }
                    TextButton(onClick = { instructionTexts.add(InstructionDraft()) }) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = null,
                            modifier = Modifier
                                .padding(end = 4.dp)
                                .size(18.dp),
                        )
                        Text("Add Step")
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 8.dp),
    )
}

/** Decodes the picked image and re-encodes it as JPEG bytes for upload. */
private fun uriToJpegBytes(context: Context, uri: Uri): ByteArray? = try {
    context.contentResolver.openInputStream(uri)?.use { stream ->
        val bitmap = BitmapFactory.decodeStream(stream)
        if (bitmap == null) {
            null
        } else {
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
            output.toByteArray()
        }
    }
} catch (e: Exception) {
    AppLog.w(TAG, "Failed to read picked image: $e", e)
    null
}
