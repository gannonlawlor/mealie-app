package com.jackabee.mealie.data.model

/** Print exactly the loaded recipe, with no server request or executable HTML from its content. */
object RecipePrintDocument {
    fun html(recipe: Recipe): String {
        fun escape(text: String) = text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")
        fun paragraph(value: String?) = if (value.isNullOrBlank()) "" else "<p>${escape(value)}</p>"
        fun field(label: String, value: String?) = if (value.isNullOrEmpty()) "" else "<p><strong>$label:</strong> ${escape(value)}</p>"
        fun duration(value: String?): String? = if (value?.startsWith("PT") == true)
            value.drop(2).replace("H", "h ").replace("M", "m ").replace("S", "s").trim() else value
        val body = buildString {
            append("<h1>${escape(recipe.name?.takeIf { it.isNotEmpty() } ?: "Recipe")}</h1>")
            append(paragraph(recipe.description))
            append("<div class='metadata'>")
            append(field("Yield", recipe.recipeYield))
            append(field("Prep", duration(recipe.prepTime)))
            append(field("Cook", duration(recipe.performTime)))
            append(field("Total", duration(recipe.totalTime)))
            append(field("Categories", recipe.recipeCategory?.mapNotNull { it.name }?.joinToString(", ")))
            append(field("Tags", recipe.tags?.mapNotNull { it.name }?.joinToString(", ")))
            append(field("Tools", recipe.tools?.mapNotNull { it.name }?.joinToString(", ")))
            append("</div>")
            if (!recipe.recipeIngredient.isNullOrEmpty()) {
                append("<h2>Ingredients</h2>")
                recipe.recipeIngredient.forEach {
                    if (!it.title.isNullOrEmpty()) append("<h3>${escape(it.title)}</h3>")
                    if (it.displayText.isNotEmpty()) append("<p class='ingredient'>${escape(it.displayText)}</p>")
                }
            }
            if (!recipe.recipeInstructions.isNullOrEmpty()) {
                append("<h2>Instructions</h2>")
                var step = 0
                recipe.recipeInstructions.forEach {
                    if (!it.title.isNullOrEmpty()) append("<h3>${escape(it.title)}</h3>")
                    if (!it.text.isNullOrEmpty()) {
                        step++
                        append("<p class='step'><strong>$step.</strong> ${escape(it.text)}</p>")
                    }
                }
            }
            recipe.nutrition?.let { n ->
                val values = field("Calories", n.calories) + field("Fat", n.fatContent) + field("Protein", n.proteinContent) +
                    field("Carbs", n.carbohydrateContent) + field("Fiber", n.fiberContent) + field("Sugar", n.sugarContent)
                if (values.isNotEmpty()) append("<h2>Nutrition</h2><div class='metadata'>$values</div>")
            }
            append(field("Source", recipe.orgURL))
        }
        return """
            <!doctype html><html><head><meta charset="utf-8"><title>${escape(recipe.name ?: "Recipe")}</title>
            <style>
            @page { margin: 0.5in; }
            body { margin: 0; font: 11pt Arial, sans-serif; color: #111; line-height: 1.45; }
            h1 { font-size: 24pt; line-height: 1.15; margin: 0 0 14pt; }
            h2 { font-size: 15pt; margin: 20pt 0 8pt; page-break-after: avoid; }
            h3 { font-size: 12pt; margin: 12pt 0 5pt; page-break-after: avoid; }
            p { margin: 0 0 8pt; white-space: pre-wrap; overflow-wrap: anywhere; word-wrap: break-word; }
            .metadata p { margin-bottom: 3pt; } .ingredient { margin-bottom: 5pt; }
            </style></head><body>$body</body></html>
        """.trimIndent()
    }
}
