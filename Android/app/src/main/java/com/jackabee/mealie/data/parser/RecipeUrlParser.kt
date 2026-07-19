package com.jackabee.mealie.data.parser

import com.jackabee.mealie.data.model.Nutrition
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.RecipeInstruction
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.store.LocalRecipeStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.time.Instant
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Mirrors Swift RecipeParseError. */
sealed class RecipeParseException(message: String) : Exception(message) {
    class InvalidUrl : RecipeParseException("Invalid URL")
    class FetchFailed(val detail: String) : RecipeParseException("Fetch failed: $detail")
    class NoRecipeFound : RecipeParseException("No recipe found on page")
    class ParsingFailed(val detail: String) : RecipeParseException("Parsing failed: $detail")
}

/**
 * The parsing capability RecipeViewModel depends on, extracted as an interface
 * so unit tests can inject a fake (implemented by [RecipeUrlParser]).
 */
interface RecipeParser {
    /** Fetches a URL, extracts JSON-LD, and returns a Recipe. Throws [RecipeParseException]. */
    suspend fun parseRecipe(urlString: String): Recipe
}

/**
 * Faithful port of ios/Sources/MealieModel/API/RecipeURLParser.swift.
 *
 * [parseRecipeFromHTML] is a pure function (no network, no disk) — the parsed
 * Recipe carries the remote image URL in `image`. [parseRecipe] fetches the
 * page, parses it, then downloads the image into [LocalRecipeStore] and swaps
 * `image` to the local file path (matching the Swift behavior end-to-end).
 */
class RecipeUrlParser(
    private val httpClient: OkHttpClient = OkHttpClient(),
    private val localRecipeStore: LocalRecipeStore? = null,
) : RecipeParser {

    private val lenientJson = Json { ignoreUnknownKeys = true; isLenient = true }

    /** Fetches a URL, extracts JSON-LD, and returns a Recipe with a locally-saved image. */
    override suspend fun parseRecipe(urlString: String): Recipe = withContext(Dispatchers.IO) {
        if (!urlString.startsWith("http://") && !urlString.startsWith("https://")) {
            throw RecipeParseException.InvalidUrl()
        }

        val html: String = try {
            fetchHtml(urlString)
        } catch (e: RecipeParseException) {
            throw e
        } catch (e: Exception) {
            throw RecipeParseException.FetchFailed(e.message ?: e.toString())
        }

        val recipe = parseRecipeFromHTML(html, urlString)

        // Download and save the image locally, mirroring Swift's mapToRecipe.
        val remoteImage = recipe.image
        val store = localRecipeStore
        if (store != null && remoteImage != null &&
            (remoteImage.startsWith("http://") || remoteImage.startsWith("https://"))
        ) {
            val imageData = try {
                downloadBytes(remoteImage)
            } catch (_: Exception) {
                null
            }
            if (imageData != null && recipe.id != null) {
                val path = store.saveImage(imageData, recipe.id)
                if (path.isNotEmpty()) return@withContext recipe.copy(image = path)
            }
            return@withContext recipe.copy(image = null)
        }
        recipe
    }

    /** Parses a recipe from raw HTML. Pure function — exposed for testing. */
    fun parseRecipeFromHTML(html: String, sourceURL: String): Recipe {
        val jsonBlocks = extractJsonLd(html)
        if (jsonBlocks.isEmpty()) throw RecipeParseException.NoRecipeFound()
        for (block in jsonBlocks) {
            findRecipe(block, sourceURL)?.let { return it }
        }
        throw RecipeParseException.NoRecipeFound()
    }

    // MARK: - Fetch

    private suspend fun fetchHtml(urlString: String): String {
        val request = Request.Builder()
            .url(urlString)
            .header(
                "User-Agent",
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                    "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            )
            .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            .header("Accept-Language", "en-US,en;q=0.9")
            .build()
        val response = httpClient.newCall(request).await()
        response.use {
            return it.body?.string()
                ?: throw RecipeParseException.FetchFailed("Could not decode HTML")
        }
    }

    private suspend fun downloadBytes(urlString: String): ByteArray? {
        val request = Request.Builder().url(urlString).build()
        val response = httpClient.newCall(request).await()
        response.use {
            if (!it.isSuccessful) return null
            return it.body?.bytes()
        }
    }

    private suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
        enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (cont.isActive) cont.resumeWithException(e)
            }

            override fun onResponse(call: Call, response: Response) {
                cont.resume(response)
            }
        })
        cont.invokeOnCancellation { cancel() }
    }

    // MARK: - JSON-LD Extraction

    private fun extractJsonLd(html: String): List<JsonElement> {
        val results = mutableListOf<JsonElement>()
        val marker = "application/ld+json"
        val endTag = "</script>"

        var searchFrom = 0
        while (true) {
            val markerIdx = html.indexOf(marker, searchFrom, ignoreCase = true)
            if (markerIdx < 0) break
            val tagClose = html.indexOf(">", markerIdx + marker.length)
            if (tagClose < 0) break
            val contentStart = tagClose + 1
            val endIdx = html.indexOf(endTag, contentStart, ignoreCase = true)
            if (endIdx < 0) break
            val jsonString = html.substring(contentStart, endIdx).trim()
            try {
                results.add(lenientJson.parseToJsonElement(jsonString))
            } catch (_: Exception) {
                // ignore malformed blocks, keep scanning
            }
            searchFrom = endIdx + endTag.length
        }
        return results
    }

    // MARK: - Recipe Finding

    private fun findRecipe(element: JsonElement, sourceURL: String): Recipe? {
        if (element is JsonObject) {
            if (isRecipeType(element)) {
                return mapToRecipe(element, sourceURL)
            }
            (element["@graph"] as? JsonArray)?.forEach { item ->
                findRecipe(item, sourceURL)?.let { return it }
            }
        }
        if (element is JsonArray) {
            element.forEach { item ->
                findRecipe(item, sourceURL)?.let { return it }
            }
        }
        return null
    }

    private fun isRecipeType(obj: JsonObject): Boolean {
        val type = obj["@type"] ?: return false
        (type as? JsonPrimitive)?.let { return it.isString && it.content == "Recipe" }
        (type as? JsonArray)?.let { arr ->
            return arr.any { it is JsonPrimitive && it.isString && it.content == "Recipe" }
        }
        return false
    }

    // MARK: - Mapping

    private fun mapToRecipe(obj: JsonObject, sourceURL: String): Recipe {
        val recipeId = UUID.randomUUID().toString()
        val rawName = obj.stringOrNull("name") ?: "Untitled"
        val name = decodeHtmlEntities(rawName)
        val slug = LocalRecipeStore.generateSlug(name)
        val description = obj.stringOrNull("description")?.let { decodeHtmlEntities(it) }

        val imageURL = extractImageUrl(obj["image"])

        val ingredients: List<RecipeIngredient>? =
            (obj["recipeIngredient"] as? JsonArray)
                ?.mapNotNull { it.stringOrNull() }
                ?.map { rawText ->
                    val text = decodeHtmlEntities(rawText)
                    RecipeIngredient(
                        quantity = null, unit = null, food = null,
                        note = text, isFood = false, disableAmount = true,
                        display = text, title = null, originalText = text,
                        referenceId = UUID.randomUUID().toString(),
                    )
                }
                ?.takeIf { it.isNotEmpty() }

        val instructions = extractInstructions(obj["recipeInstructions"])

        val prepTime = obj.stringOrNull("prepTime")
        val cookTime = obj.stringOrNull("cookTime")
        val totalTime = obj.stringOrNull("totalTime")

        val recipeYield = extractYield(obj["recipeYield"])
        val nutrition = extractNutrition(obj["nutrition"])

        val categories: List<RecipeCategory>? = extractStringList(obj["recipeCategory"])?.map { n ->
            RecipeCategory(
                id = UUID.randomUUID().toString(),
                name = n,
                slug = LocalRecipeStore.generateSlug(n),
            )
        }

        val tags: List<RecipeTag>? = extractStringList(obj["keywords"])?.map { n ->
            RecipeTag(
                id = UUID.randomUUID().toString(),
                name = n,
                slug = LocalRecipeStore.generateSlug(n),
            )
        }

        val now = Instant.now().toString()

        return Recipe(
            id = recipeId,
            slug = slug,
            name = name,
            description = description,
            image = imageURL,
            recipeCategory = categories,
            tags = tags,
            tools = null,
            rating = null,
            recipeYield = recipeYield,
            recipeIngredient = ingredients,
            recipeInstructions = instructions,
            totalTime = totalTime,
            prepTime = prepTime,
            performTime = cookTime,
            nutrition = nutrition,
            settings = null,
            dateAdded = now,
            dateUpdated = now,
            createdAt = now,
            updatedAt = now,
            orgURL = sourceURL,
            extras = null,
        )
    }

    // MARK: - Field Extractors

    private fun extractImageUrl(value: JsonElement?): String? {
        value ?: return null
        value.stringOrNull()?.let { return it }
        (value as? JsonObject)?.let { return it.stringOrNull("url") }
        (value as? JsonArray)?.firstOrNull()?.let { first ->
            first.stringOrNull()?.let { return it }
            (first as? JsonObject)?.let { return it.stringOrNull("url") }
        }
        return null
    }

    private fun extractInstructions(value: JsonElement?): List<RecipeInstruction>? {
        val array = value as? JsonArray ?: return null

        // Array of strings
        if (array.isNotEmpty() && array.all { it is JsonPrimitive && it.isString }) {
            return array.map { el ->
                RecipeInstruction(
                    id = UUID.randomUUID().toString(),
                    title = null,
                    text = decodeHtmlEntities(el.stringOrNull() ?: ""),
                    ingredientReferences = null,
                )
            }
        }

        // Array of HowToStep / HowToSection objects
        val objects = array.filterIsInstance<JsonObject>()
        if (objects.isEmpty()) return null
        val mapped = objects.mapNotNull { dict ->
            val sectionName = dict.stringOrNull("name")
            val sectionItems = dict["itemListElement"] as? JsonArray
            if (sectionName != null && sectionItems != null) {
                // HowToSection: Swift keeps only the first step of each section — kept for parity.
                val steps = sectionItems.filterIsInstance<JsonObject>().mapNotNull { item ->
                    item.stringOrNull("text")?.let { text ->
                        RecipeInstruction(
                            id = UUID.randomUUID().toString(),
                            title = decodeHtmlEntities(sectionName),
                            text = decodeHtmlEntities(text),
                            ingredientReferences = null,
                        )
                    }
                }
                return@mapNotNull steps.firstOrNull()
            }
            dict.stringOrNull("text")?.let { text ->
                RecipeInstruction(
                    id = UUID.randomUUID().toString(),
                    title = null,
                    text = decodeHtmlEntities(text),
                    ingredientReferences = null,
                )
            }
        }
        return mapped.ifEmpty { null }
    }

    private fun extractYield(value: JsonElement?): String? {
        value ?: return null
        value.stringOrNull()?.let { return it }
        (value as? JsonArray)?.firstOrNull()?.stringOrNull()?.let { return it }
        (value as? JsonPrimitive)?.intOrNull?.let { return it.toString() }
        return null
    }

    private fun extractNutrition(value: JsonElement?): Nutrition? {
        val dict = value as? JsonObject ?: return null
        return Nutrition(
            calories = dict.stringOrNull("calories"),
            fatContent = dict.stringOrNull("fatContent"),
            proteinContent = dict.stringOrNull("proteinContent"),
            carbohydrateContent = dict.stringOrNull("carbohydrateContent"),
            fiberContent = dict.stringOrNull("fiberContent"),
            sodiumContent = dict.stringOrNull("sodiumContent"),
            sugarContent = dict.stringOrNull("sugarContent"),
        )
    }

    /** String array, or comma-separated string (used for categories and keywords). */
    private fun extractStringList(value: JsonElement?): List<String>? {
        value ?: return null
        (value as? JsonArray)?.let { arr ->
            val items = arr.mapNotNull { it.stringOrNull() }
            return items.ifEmpty { null }
        }
        value.stringOrNull()?.let { str ->
            val items = str.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            return items.ifEmpty { null }
        }
        return null
    }

    // MARK: - JSON helpers

    private fun JsonElement.stringOrNull(): String? =
        (this as? JsonPrimitive)?.takeIf { it.isString }?.content

    private fun JsonObject.stringOrNull(key: String): String? = this[key]?.stringOrNull()

    companion object {

        private val namedEntities: Map<String, String> = mapOf(
            "&amp;" to "&", "&lt;" to "<", "&gt;" to ">", "&quot;" to "\"",
            "&apos;" to "'", "&nbsp;" to " ",
            "&frac12;" to "½", "&frac13;" to "⅓", "&frac14;" to "¼",
            "&frac15;" to "⅕", "&frac16;" to "⅙", "&frac18;" to "⅛",
            "&frac23;" to "⅔", "&frac25;" to "⅖", "&frac34;" to "¾",
            "&frac35;" to "⅗", "&frac38;" to "⅜", "&frac45;" to "⅘",
            "&frac56;" to "⅚", "&frac58;" to "⅝", "&frac78;" to "⅞",
            "&deg;" to "°", "&mdash;" to "—", "&ndash;" to "–",
            "&lsquo;" to "‘", "&rsquo;" to "’",
            "&ldquo;" to "“", "&rdquo;" to "”",
            "&hellip;" to "…", "&trade;" to "™", "&copy;" to "©",
            "&reg;" to "®", "&times;" to "×",
        )

        /**
         * Mirrors Swift decodeHTMLEntities: the same named entities (incl. fraction
         * glyphs) plus numeric &#NNN; and &#xHH; forms.
         */
        fun decodeHtmlEntities(string: String): String {
            var result = string
            for ((entity, replacement) in namedEntities) {
                result = result.replace(entity, replacement)
            }

            // Numeric entities: &#8217; &#x2153; etc.
            while (true) {
                val start = result.indexOf("&#")
                if (start < 0) break
                val end = result.indexOf(";", start + 2)
                if (end < 0) break
                val numberStr = result.substring(start + 2, end)
                val codePoint: Int? =
                    if (numberStr.startsWith("x") || numberStr.startsWith("X")) {
                        numberStr.drop(1).toIntOrNull(16)
                    } else {
                        numberStr.toIntOrNull()
                    }
                if (codePoint != null && Character.isValidCodePoint(codePoint)) {
                    result = result.substring(0, start) +
                        String(Character.toChars(codePoint)) +
                        result.substring(end + 1)
                } else {
                    // Can't decode; stop to avoid an infinite loop (same as Swift).
                    break
                }
            }

            return result
        }
    }
}
