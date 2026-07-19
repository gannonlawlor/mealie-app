package com.jackabee.mealie

import com.jackabee.mealie.data.parser.RecipeParseException
import com.jackabee.mealie.data.parser.RecipeUrlParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class RecipeUrlParserTest {

    private val parser = RecipeUrlParser()
    private val sourceUrl = "https://example.com/recipe"

    private fun html(jsonLd: String, scriptAttrs: String = """type="application/ld+json""""): String = """
        <!DOCTYPE html>
        <html><head>
        <title>Some Recipe Page</title>
        <script $scriptAttrs>
        $jsonLd
        </script>
        </head><body><p>hello</p></body></html>
    """.trimIndent()

    @Test
    fun `parses plain recipe object with HowToStep instructions`() {
        val jsonLd = """
        {
            "@context": "https://schema.org",
            "@type": "Recipe",
            "name": "Chocolate Cake",
            "description": "Rich and moist",
            "image": "https://example.com/cake.jpg",
            "recipeYield": "8",
            "prepTime": "PT20M",
            "cookTime": "PT35M",
            "totalTime": "PT55M",
            "recipeIngredient": ["2 cups flour", "1 cup sugar"],
            "recipeInstructions": [
                {"@type": "HowToStep", "text": "Preheat oven to 350F."},
                {"@type": "HowToStep", "text": "Mix dry ingredients."}
            ],
            "recipeCategory": "Dessert",
            "keywords": "cake, chocolate, baking",
            "nutrition": {"@type": "NutritionInformation", "calories": "450 kcal", "fatContent": "20 g"}
        }
        """.trimIndent()

        val recipe = parser.parseRecipeFromHTML(html(jsonLd), sourceUrl)
        assertEquals("Chocolate Cake", recipe.name)
        assertEquals("chocolate-cake", recipe.slug)
        assertEquals("Rich and moist", recipe.description)
        assertEquals("https://example.com/cake.jpg", recipe.image)
        assertEquals("8", recipe.recipeYield)
        assertEquals("PT20M", recipe.prepTime)
        assertEquals("PT35M", recipe.performTime)
        assertEquals("PT55M", recipe.totalTime)
        assertEquals(listOf("2 cups flour", "1 cup sugar"), recipe.recipeIngredient?.map { it.displayText })
        assertEquals(
            listOf("Preheat oven to 350F.", "Mix dry ingredients."),
            recipe.recipeInstructions?.map { it.text },
        )
        assertEquals(listOf("Dessert"), recipe.recipeCategory?.map { it.name })
        assertEquals(listOf("cake", "chocolate", "baking"), recipe.tags?.map { it.name })
        assertEquals("450 kcal", recipe.nutrition?.calories)
        assertEquals("20 g", recipe.nutrition?.fatContent)
        assertEquals(sourceUrl, recipe.orgURL)
    }

    @Test
    fun `finds recipe inside @graph`() {
        val jsonLd = """
        {
            "@context": "https://schema.org",
            "@graph": [
                {"@type": "WebSite", "name": "Example Site"},
                {"@type": ["Recipe", "Thing"], "name": "Graph Soup",
                 "recipeIngredient": ["1 onion"],
                 "recipeInstructions": ["Chop the onion.", "Simmer for an hour."]},
                {"@type": "BreadcrumbList"}
            ]
        }
        """.trimIndent()

        val recipe = parser.parseRecipeFromHTML(html(jsonLd), sourceUrl)
        assertEquals("Graph Soup", recipe.name)
        // string-array instructions
        assertEquals(
            listOf("Chop the onion.", "Simmer for an hour."),
            recipe.recipeInstructions?.map { it.text },
        )
        assertNull(recipe.recipeInstructions?.get(0)?.title)
    }

    @Test
    fun `finds recipe in top-level array and case-insensitive script tag`() {
        val jsonLd = """[{"@type": "Recipe", "name": "Array Recipe", "recipeYield": 6}]"""
        val recipe = parser.parseRecipeFromHTML(
            html(jsonLd, scriptAttrs = """TYPE="APPLICATION/LD+JSON""""),
            sourceUrl,
        )
        assertEquals("Array Recipe", recipe.name)
        // integer yield becomes a string
        assertEquals("6", recipe.recipeYield)
    }

    @Test
    fun `decodes html entities including fractions and numeric forms`() {
        val jsonLd = """
        {
            "@type": "Recipe",
            "name": "Mom&#8217;s &frac12; Sugar Cookies &amp; Cream",
            "recipeIngredient": ["&frac12; cup butter", "1&frac34; cups flour &#x2153; extra"],
            "recipeInstructions": [{"text": "Don&#8217;t overmix &mdash; fold gently."}]
        }
        """.trimIndent()

        val recipe = parser.parseRecipeFromHTML(html(jsonLd), sourceUrl)
        assertEquals("Mom’s ½ Sugar Cookies & Cream", recipe.name)
        assertEquals("½ cup butter", recipe.recipeIngredient?.get(0)?.displayText)
        assertEquals("1¾ cups flour ⅓ extra", recipe.recipeIngredient?.get(1)?.displayText)
        assertEquals("Don’t overmix — fold gently.", recipe.recipeInstructions?.get(0)?.text)
    }

    @Test
    fun `image object and array forms are handled`() {
        val objForm = """{"@type": "Recipe", "name": "A", "image": {"@type": "ImageObject", "url": "https://img/a.jpg"}}"""
        assertEquals("https://img/a.jpg", parser.parseRecipeFromHTML(html(objForm), sourceUrl).image)

        val arrForm = """{"@type": "Recipe", "name": "B", "image": ["https://img/b.jpg", "https://img/b2.jpg"]}"""
        assertEquals("https://img/b.jpg", parser.parseRecipeFromHTML(html(arrForm), sourceUrl).image)

        val arrObjForm = """{"@type": "Recipe", "name": "C", "image": [{"url": "https://img/c.jpg"}]}"""
        assertEquals("https://img/c.jpg", parser.parseRecipeFromHTML(html(arrObjForm), sourceUrl).image)
    }

    @Test
    fun `keywords as array and yield as array`() {
        val jsonLd = """
        {
            "@type": "Recipe",
            "name": "Keyword Test",
            "keywords": ["quick", "easy"],
            "recipeYield": ["4 servings", "4"]
        }
        """.trimIndent()

        val recipe = parser.parseRecipeFromHTML(html(jsonLd), sourceUrl)
        assertEquals(listOf("quick", "easy"), recipe.tags?.map { it.name })
        assertEquals("4 servings", recipe.recipeYield)
    }

    @Test
    fun `HowToSection keeps first step per section with section title`() {
        val jsonLd = """
        {
            "@type": "Recipe",
            "name": "Sectioned",
            "recipeInstructions": [
                {
                    "@type": "HowToSection",
                    "name": "Dough",
                    "itemListElement": [
                        {"@type": "HowToStep", "text": "Knead the dough."},
                        {"@type": "HowToStep", "text": "Let it rest."}
                    ]
                },
                {"@type": "HowToStep", "text": "Bake it."}
            ]
        }
        """.trimIndent()

        val recipe = parser.parseRecipeFromHTML(html(jsonLd), sourceUrl)
        val instructions = recipe.recipeInstructions
        assertNotNull(instructions)
        // Mirrors the Swift behavior: only the first step of the section survives.
        assertEquals(2, instructions!!.size)
        assertEquals("Dough", instructions[0].title)
        assertEquals("Knead the dough.", instructions[0].text)
        assertEquals("Bake it.", instructions[1].text)
    }

    @Test
    fun `no json-ld or no recipe type throws NoRecipeFound`() {
        assertThrows(RecipeParseException.NoRecipeFound::class.java) {
            parser.parseRecipeFromHTML("<html><body>No structured data</body></html>", sourceUrl)
        }
        assertThrows(RecipeParseException.NoRecipeFound::class.java) {
            parser.parseRecipeFromHTML(html("""{"@type": "WebSite", "name": "Nope"}"""), sourceUrl)
        }
    }

    @Test
    fun `untitled recipe gets fallback name and slug`() {
        val recipe = parser.parseRecipeFromHTML(html("""{"@type": "Recipe"}"""), sourceUrl)
        assertEquals("Untitled", recipe.name)
        assertEquals("untitled", recipe.slug)
    }
}
