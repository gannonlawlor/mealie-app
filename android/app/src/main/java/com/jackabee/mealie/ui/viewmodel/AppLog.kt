package com.jackabee.mealie.ui.viewmodel

import android.util.Log

/**
 * Logcat logging with a `println` fallback.
 *
 * `android.util.Log` throws `RuntimeException("Method ... not mocked")` under
 * plain-JVM unit tests, so every catch-block log goes through [w]: logcat on
 * device, `println` under tests.
 */
internal object AppLog {
    fun w(tag: String, msg: String, tr: Throwable? = null) {
        try {
            if (tr != null) Log.w(tag, msg, tr) else Log.w(tag, msg)
        } catch (_: RuntimeException) {
            println("$tag: $msg")
        }
    }
}
