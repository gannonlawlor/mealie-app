package com.jackabee.mealie.ui.screens.recipes.components

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.text.Html
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipePrintDocument
import java.io.File
import java.io.OutputStream
import java.util.UUID

/** Uses the same printable content, with native text layout and whole-line page breaks. */
object RecipePDFRenderer {
    fun write(recipe: Recipe, output: OutputStream) {
        val body = RecipePrintDocument.html(recipe).substringAfter("<body>").substringBefore("</body>")
        val text = Html.fromHtml(body.replace("\n", "<br>"), Html.FROM_HTML_MODE_LEGACY)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; color = Color.BLACK }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, 540)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(3f, 1f)
            .setIncludePad(true).build()
        val document = PdfDocument()
        try {
            var firstLine = 0
            var pageNumber = 1
            while (firstLine < layout.lineCount) {
                val top = layout.getLineTop(firstLine)
                var endLine = firstLine + 1
                while (endLine < layout.lineCount && layout.getLineBottom(endLine) - top <= 720) endLine++
                val bottom = layout.getLineBottom(endLine - 1)
                val page = document.startPage(PdfDocument.PageInfo.Builder(612, 792, pageNumber++).create())
                try {
                    page.canvas.save()
                    page.canvas.translate(36f, 36f)
                    page.canvas.clipRect(0f, 0f, 540f, (bottom - top).toFloat())
                    page.canvas.translate(0f, -top.toFloat())
                    layout.draw(page.canvas)
                    page.canvas.restore()
                } finally { document.finishPage(page) }
                firstLine = endLine
            }
            document.writeTo(output)
        } finally { document.close() }
    }
}

object RecipeSharer {
    // Caller runs preparation off the UI thread, then launches the system chooser on the UI thread.
    fun prepare(context: Context, recipe: Recipe): Intent {
        val root = File(context.cacheDir, "shared_recipes").apply { check(mkdirs() || isDirectory) }
        val cutoff = System.currentTimeMillis() - 86_400_000L
        root.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.deleteRecursively() }
        val folder = File(root, UUID.randomUUID().toString()).apply { check(mkdir()) }
        val name = recipe.name.orEmpty().map { if (it.isLetterOrDigit() || it == ' ' || it == '-') it else '_' }
            .joinToString("").take(60).trim().ifEmpty { "Recipe" }
        val file = File(folder, "$name.pdf")
        try {
            file.outputStream().use { RecipePDFRenderer.write(recipe, it) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.recipe-files", file)
            return Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, recipe.name ?: "Recipe")
                clipData = ClipData.newRawUri("Recipe PDF", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        } catch (error: Exception) {
            folder.deleteRecursively()
            throw error
        }
    }
}
