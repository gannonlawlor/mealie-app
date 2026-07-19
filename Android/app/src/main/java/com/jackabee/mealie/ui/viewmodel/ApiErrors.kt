package com.jackabee.mealie.ui.viewmodel

import kotlinx.serialization.SerializationException
import retrofit2.HttpException
import java.io.IOException

/** Reads an HTTP error response body once, safely (it can only be consumed once). */
internal fun httpErrorBody(error: HttpException): String = try {
    error.response()?.errorBody()?.string() ?: ""
} catch (_: Exception) {
    ""
}

/**
 * Port of AppEnvironment.errorDetail (ios/Sources/MealieModel/API/AppEnvironment.swift):
 * formats an error into a human-readable detail string for debug banners.
 */
internal fun errorDetail(error: Throwable): String = when (error) {
    is HttpException ->
        if (error.code() == 401) "Unauthorized (401)"
        else "Server error ${error.code()}: ${httpErrorBody(error).take(200)}"
    is SerializationException -> "Decoding error: ${error.message}"
    is IOException -> "Network error: ${error.message}"
    else -> error.toString()
}
