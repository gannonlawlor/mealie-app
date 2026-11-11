package com.jackabee.mealie.ui.screens.recipes.components

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.text.Html
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.URLSpan
import androidx.core.content.FileProvider
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipePrintDocument
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.interactive.action.PDActionURI
import com.tom_roush.pdfbox.pdmodel.interactive.annotation.PDAnnotationLink
import com.tom_roush.pdfbox.pdmodel.interactive.annotation.PDBorderStyleDictionary
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.OutputStream
import java.util.UUID

/** Uses the same printable content, with native text layout and whole-line page breaks. */
object RecipePDFRenderer {
    private data class Link(val page: Int, val url: String, val bounds: PDRectangle)

    fun write(recipe: Recipe, output: OutputStream) {
        val body = RecipePrintDocument.html(recipe).substringAfter("<body>").substringBefore("</body>")
        val text = Html.fromHtml(body.replace("\n", "<br>"), Html.FROM_HTML_MODE_LEGACY)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 11f; color = Color.BLACK; linkColor = Color.rgb(21, 101, 192)
        }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, 540)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(3f, 1f)
            .setIncludePad(true).build()
        val document = PdfDocument()
        val links = mutableListOf<Link>()
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
                // Android's PDF canvas draws URLSpan styling but does not emit PDF link annotations.
                for (span in text.getSpans(0, text.length, URLSpan::class.java)) {
                    for (line in firstLine until endLine) {
                        val start = maxOf(text.getSpanStart(span), layout.getLineStart(line))
                        val end = minOf(text.getSpanEnd(span), layout.getLineEnd(line))
                        if (start >= end) continue
                        val path = Path()
                        layout.getSelectionPath(start, end, path)
                        val bounds = RectF()
                        path.computeBounds(bounds, true)
                        links += Link(pageNumber - 2, span.url, PDRectangle(36 + bounds.left,
                            792 - 36 - (bounds.bottom - top), bounds.width(), bounds.height()))
                    }
                }
                firstLine = endLine
            }
            if (links.isEmpty()) {
                document.writeTo(output)
            } else {
                val buffer = ByteArrayOutputStream()
                document.writeTo(buffer)
                PDDocument.load(buffer.toByteArray()).use { pdf ->
                    for (link in links) {
                        pdf.getPage(link.page).annotations.add(PDAnnotationLink().apply {
                            rectangle = link.bounds
                            action = PDActionURI().apply { uri = link.url }
                            borderStyle = PDBorderStyleDictionary().apply { width = 0f }
                        })
                    }
                    pdf.save(output)
                }
            }
        } finally { document.close() }
    }
}

object RecipeSharer {
    // Caller runs preparation off the UI thread, then launches the system chooser on the UI thread.
    fun prepare(context: Context, recipe: Recipe): Intent {
        PDFBoxResourceLoader.init(context.applicationContext)
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
