package com.jackabee.mealie.data.model

/** A row retains its source object when neighboring rows are inserted or removed. */
data class IngredientDraft(val original: RecipeIngredient? = null, val text: String = original?.displayText.orEmpty()) {
    fun value(): RecipeIngredient? {
        if (original != null && text == original.displayText) return original
        return text.takeIf { it.isNotEmpty() }?.let {
            RecipeIngredient(note = it, isFood = false, disableAmount = true, display = it,
                originalText = it, title = original?.title, referenceId = original?.referenceId)
        }
    }
}

data class InstructionDraft(val original: RecipeInstruction? = null, val text: String = original?.text.orEmpty()) {
    fun value(): RecipeInstruction? {
        if (original != null && text == original.text.orEmpty()) return original
        return text.takeIf { it.isNotEmpty() }?.let {
            original?.copy(text = it) ?: RecipeInstruction(text = it)
        }
    }
}

/** Only options actually shown in the editor can be deselected. */
fun <T> editedAssociations(original: List<T>, available: List<T>, selected: Collection<String>, id: (T) -> String?): List<T> {
    val editableIds = available.mapNotNull(id).toSet()
    val originalIds = original.mapNotNull(id).toSet()
    return original.filter { id(it) !in editableIds || id(it) in selected } +
        available.filter { id(it) != null && id(it) in selected && id(it) !in originalIds }
}
