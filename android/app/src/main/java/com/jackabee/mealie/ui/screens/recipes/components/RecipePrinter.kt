package com.jackabee.mealie.ui.screens.recipes.components

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipePrintDocument
import com.jackabee.mealie.ui.viewmodel.AppLog

/** Android's native print preview includes Save as PDF; the document never loads remote content. */
object RecipePrinter {
    fun print(context: Context, recipe: Recipe, onReady: () -> Unit, onError: (String) -> Unit) {
        val activity = context.activity()
        if (activity == null || activity.isFinishing) {
            onError("Printing is unavailable. Please try again.")
            return
        }
        val webView = try { WebView(activity) } catch (error: Exception) {
            AppLog.w("RecipePrinter", "Could not open print renderer", error)
            onError("Printing is unavailable. Please try again.")
            return
        }
        webView.settings.javaScriptEnabled = false
        webView.settings.blockNetworkLoads = true
        webView.settings.allowFileAccess = false
        var submitted = false
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                if (submitted) return
                submitted = true
                try {
                    val name = recipe.name?.takeIf { it.isNotBlank() } ?: "Recipe"
                    val adapter = view.createPrintDocumentAdapter(name)
                    val retained = object : PrintDocumentAdapter() {
                        override fun onStart() = adapter.onStart()
                        override fun onLayout(oldAttributes: PrintAttributes?, newAttributes: PrintAttributes,
                            cancellationSignal: CancellationSignal, callback: LayoutResultCallback, extras: Bundle?) =
                            adapter.onLayout(oldAttributes, newAttributes, cancellationSignal, callback, extras)
                        override fun onWrite(pages: Array<out PageRange>, destination: ParcelFileDescriptor,
                            cancellationSignal: CancellationSignal, callback: WriteResultCallback) =
                            adapter.onWrite(pages, destination, cancellationSignal, callback)
                        override fun onFinish() {
                            adapter.onFinish()
                            view.destroy()
                        }
                    }
                    val manager = activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
                    manager.print(name, retained, PrintAttributes.Builder()
                        .setMinMargins(PrintAttributes.Margins(500, 500, 500, 500)).build())
                    onReady()
                } catch (error: Exception) {
                    AppLog.w("RecipePrinter", "Could not start recipe printing", error)
                    view.destroy()
                    onError("Could not prepare this recipe for printing. Please try again.")
                }
            }
            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame && !submitted) {
                    submitted = true
                    AppLog.w("RecipePrinter", "Print document load failed: ${error.errorCode}")
                    view.destroy()
                    onError("Could not prepare this recipe for printing. Please try again.")
                }
            }
        }
        webView.loadDataWithBaseURL(null, RecipePrintDocument.html(recipe), "text/html", "UTF-8", null)
    }

    private fun Context.activity(): Activity? = when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext.takeIf { it !== this }?.activity()
        else -> null
    }
}
