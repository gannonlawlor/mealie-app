package com.jackabee.mealie.data.model

import kotlinx.serialization.json.Json

/**
 * Single shared Json instance for the whole app.
 *
 * - ignoreUnknownKeys: Mealie responses contain many fields we do not model.
 * - explicitNulls = false: null fields are omitted when encoding (mirrors Swift's
 *   JSONEncoder encodeIfPresent behavior) and missing keys decode as null.
 * - encodeDefaults = false: values equal to their declared default are omitted;
 *   fields that must always be sent are annotated with @EncodeDefault(ALWAYS).
 */
val MealieJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = false
}
