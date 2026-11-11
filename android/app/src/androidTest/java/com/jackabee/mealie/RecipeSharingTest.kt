package com.jackabee.mealie

import android.app.Application
import android.content.Intent
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeInstruction
import com.jackabee.mealie.ui.screens.recipes.components.RecipeSharer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress

@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 35)
class RecipeSharingTest {
    private val context = ApplicationProvider.getApplicationContext<Application>()

    @Test fun originalRecipeIsClickableNearTopOfSharedPdf() {
        val url = "https://example.com/recipes/soup?servings=4&unit=metric"
        val intent = RecipeSharer.prepare(context, Recipe(name = "Soup", orgURL = url, description = "A cozy soup."))
        val uri = intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
        context.contentResolver.openFileDescriptor(uri, "r")!!.use { descriptor ->
            PdfRenderer(descriptor).use { pdf ->
                pdf.openPage(0).use { page ->
                    val text = page.textContents.joinToString(" ") { it.text }
                    assertTrue("Links: ${page.linkContents.map { it.uri }}; text: $text",
                        page.linkContents.any { it.uri.toString() == url })
                    val link = page.linkContents.single { it.uri.toString() == url }
                    assertTrue(link.bounds.isNotEmpty())
                    assertTrue(link.bounds.all { it.top >= 36 && it.bottom < page.height * 0.25 })
                    assertTrue(text.contains("Original recipe: example.com"))
                    assertTrue(text.indexOf("Original recipe:") < text.indexOf("A cozy soup."))
                }
            }
        }
    }

    @Test fun shareDefaultsToReadablePdfAttachmentWithTemporaryReadAccess() {
        val recipe = Recipe(name = "Soup / family: recipe", orgURL = "https://example.com/soup", recipeInstructions = (1..70).map {
            RecipeInstruction(text = "Instruction $it: " + "Stir gently and check the texture. ".repeat(8))
        })
        val intent = RecipeSharer.prepare(context, recipe)
        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals("application/pdf", intent.type)
        assertFalse(intent.hasExtra(Intent.EXTRA_TEXT))
        assertTrue(intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        assertEquals(0, intent.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        val uri = intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
        assertEquals("content", uri.scheme)
        assertEquals(uri, intent.clipData!!.getItemAt(0).uri)
        assertTrue(uri.lastPathSegment!!.endsWith(".pdf"))
        context.contentResolver.openInputStream(uri)!!.use {
            assertEquals("%PDF", String(it.readNBytes(4)))
        }
        context.contentResolver.openFileDescriptor(uri, "r")!!.use { descriptor ->
            PdfRenderer(descriptor).use { pdf ->
                assertTrue(pdf.pageCount > 1)
                pdf.openPage(pdf.pageCount - 1).use { page ->
                    assertEquals(612, page.width)
                    assertEquals(792, page.height)
                    val text = page.textContents.joinToString(" ") { it.text }
                    assertTrue(text, text.contains("Instruction 70:"))
                }
            }
        }
    }

    @Test fun repeatedSharesKeepSeparateFilesAndPurgeOnlyExpiredExports() {
        val first = RecipeSharer.prepare(context, Recipe(name = "Same recipe"))
            .getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
        val root = java.io.File(context.cacheDir, "shared_recipes")
        val expired = java.io.File(root, "expired").apply { mkdirs() }
        java.io.File(expired, "old.pdf").writeText("old")
        expired.setLastModified(System.currentTimeMillis() - 172_800_000L)
        val next = RecipeSharer.prepare(context, Recipe(name = "Same recipe"))
            .getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)!!
        assertNotEquals(first, next)
        assertFalse(expired.exists())
        context.contentResolver.openInputStream(first)!!.close()
        context.contentResolver.openInputStream(next)!!.close()
    }
}
