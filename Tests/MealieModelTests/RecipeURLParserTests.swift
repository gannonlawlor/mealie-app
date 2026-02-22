import XCTest
import Foundation
@testable import MealieModel

final class RecipeURLParserTests: XCTestCase {
    let parser = RecipeURLParser.shared

    // MARK: - Basic JSON-LD Parsing

    func testParsesBasicRecipeFromJSONLD() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Chocolate Cake",
            "description": "A rich chocolate cake",
            "prepTime": "PT15M",
            "cookTime": "PT30M",
            "totalTime": "PT45M",
            "recipeYield": "8 servings",
            "recipeIngredient": ["2 cups flour", "1 cup sugar", "3 eggs"],
            "recipeInstructions": [
                {"@type": "HowToStep", "text": "Mix dry ingredients"},
                {"@type": "HowToStep", "text": "Add wet ingredients"},
                {"@type": "HowToStep", "text": "Bake at 350F for 30 minutes"}
            ]
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com/cake")

        XCTAssertEqual(recipe.name, "Chocolate Cake")
        XCTAssertEqual(recipe.description, "A rich chocolate cake")
        XCTAssertEqual(recipe.prepTime, "PT15M")
        XCTAssertEqual(recipe.performTime, "PT30M") // cookTime maps to performTime
        XCTAssertEqual(recipe.totalTime, "PT45M")
        XCTAssertEqual(recipe.recipeYield, "8 servings")
        XCTAssertEqual(recipe.orgURL, "https://example.com/cake")
        XCTAssertNotNil(recipe.id)
        XCTAssertNotNil(recipe.slug)
        XCTAssertEqual(recipe.slug, "chocolate-cake")
    }

    func testParsesIngredients() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeIngredient": ["2 cups flour", "1 tsp salt", "3 tbsp butter"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")

        XCTAssertEqual(recipe.recipeIngredient?.count, 3)
        XCTAssertEqual(recipe.recipeIngredient?[0].display, "2 cups flour")
        XCTAssertEqual(recipe.recipeIngredient?[0].note, "2 cups flour")
        XCTAssertEqual(recipe.recipeIngredient?[0].originalText, "2 cups flour")
        XCTAssertEqual(recipe.recipeIngredient?[1].display, "1 tsp salt")
        XCTAssertEqual(recipe.recipeIngredient?[2].display, "3 tbsp butter")
    }

    func testParsesInstructionsAsStrings() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeInstructions": ["Step one", "Step two", "Step three"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")

        XCTAssertEqual(recipe.recipeInstructions?.count, 3)
        XCTAssertEqual(recipe.recipeInstructions?[0].text, "Step one")
        XCTAssertEqual(recipe.recipeInstructions?[1].text, "Step two")
        XCTAssertEqual(recipe.recipeInstructions?[2].text, "Step three")
    }

    func testParsesInstructionsAsHowToSteps() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeInstructions": [
            {"@type": "HowToStep", "text": "Preheat oven"},
            {"@type": "HowToStep", "text": "Mix batter"}
        ]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")

        XCTAssertEqual(recipe.recipeInstructions?.count, 2)
        XCTAssertEqual(recipe.recipeInstructions?[0].text, "Preheat oven")
        XCTAssertEqual(recipe.recipeInstructions?[1].text, "Mix batter")
    }

    // MARK: - @graph Wrapper

    func testParsesRecipeFromGraphWrapper() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
            "@context": "https://schema.org",
            "@graph": [
                {"@type": "WebPage", "name": "Some Page"},
                {"@type": "Recipe", "name": "Graph Recipe", "recipeIngredient": ["1 cup water"]}
            ]
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Graph Recipe")
        XCTAssertEqual(recipe.recipeIngredient?.count, 1)
    }

    // MARK: - @type as Array

    func testParsesRecipeWithTypeArray() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": ["Recipe"], "name": "Type Array Recipe"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Type Array Recipe")
    }

    // MARK: - Nutrition

    func testParsesNutrition() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Healthy Bowl",
            "nutrition": {
                "@type": "NutritionInformation",
                "calories": "450 calories",
                "fatContent": "12g",
                "proteinContent": "25g",
                "carbohydrateContent": "55g",
                "fiberContent": "8g",
                "sodiumContent": "300mg",
                "sugarContent": "6g"
            }
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")

        XCTAssertNotNil(recipe.nutrition)
        XCTAssertEqual(recipe.nutrition?.calories, "450 calories")
        XCTAssertEqual(recipe.nutrition?.fatContent, "12g")
        XCTAssertEqual(recipe.nutrition?.proteinContent, "25g")
        XCTAssertEqual(recipe.nutrition?.carbohydrateContent, "55g")
        XCTAssertEqual(recipe.nutrition?.fiberContent, "8g")
        XCTAssertEqual(recipe.nutrition?.sodiumContent, "300mg")
        XCTAssertEqual(recipe.nutrition?.sugarContent, "6g")
    }

    // MARK: - Categories and Keywords

    func testParsesCategoryAsArray() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeCategory": ["Dinner", "Italian"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeCategory?.count, 2)
        XCTAssertEqual(recipe.recipeCategory?[0].name, "Dinner")
        XCTAssertEqual(recipe.recipeCategory?[1].name, "Italian")
    }

    func testParsesCategoryAsCommaSeparatedString() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeCategory": "Dessert, Baking"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeCategory?.count, 2)
        XCTAssertEqual(recipe.recipeCategory?[0].name, "Dessert")
        XCTAssertEqual(recipe.recipeCategory?[1].name, "Baking")
    }

    func testParsesKeywordsAsCommaSeparatedString() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "keywords": "easy, quick, weeknight"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.tags?.count, 3)
        let tagNames = recipe.tags?.compactMap { $0.name } ?? []
        XCTAssertTrue(tagNames.contains("easy"))
        XCTAssertTrue(tagNames.contains("quick"))
        XCTAssertTrue(tagNames.contains("weeknight"))
    }

    func testParsesKeywordsAsArray() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "keywords": ["vegan", "gluten-free"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.tags?.count, 2)
    }

    // MARK: - Yield Variations

    func testParsesYieldAsString() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeYield": "4 servings"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeYield, "4 servings")
    }

    func testParsesYieldAsArray() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test", "recipeYield": ["12 cookies", "6 servings"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeYield, "12 cookies")
    }

    // MARK: - Error Cases

    func testThrowsNoRecipeFoundForEmptyHTML() {
        let html = "<html><head></head><body>No recipe here</body></html>"

        XCTAssertThrowsError(try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")) { error in
            guard let parseError = error as? RecipeParseError else {
                XCTFail("Expected RecipeParseError")
                return
            }
            if case .noRecipeFound = parseError {
                // expected
            } else {
                XCTFail("Expected .noRecipeFound, got \(parseError)")
            }
        }
    }

    func testThrowsNoRecipeFoundForNonRecipeJSONLD() {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Organization", "name": "Some Company"}
        </script>
        </head><body></body></html>
        """

        XCTAssertThrowsError(try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")) { error in
            guard let parseError = error as? RecipeParseError else {
                XCTFail("Expected RecipeParseError")
                return
            }
            if case .noRecipeFound = parseError {
                // expected
            } else {
                XCTFail("Expected .noRecipeFound, got \(parseError)")
            }
        }
    }

    // MARK: - Generated IDs

    func testEachParsedRecipeGetsUniqueId() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Test Recipe"}
        </script>
        </head><body></body></html>
        """

        let recipe1 = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        let recipe2 = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")

        XCTAssertNotEqual(recipe1.id, recipe2.id, "Each parse should generate a unique ID")
    }

    func testParsedRecipeHasTimestamps() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Timestamped"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertNotNil(recipe.dateAdded)
        XCTAssertNotNil(recipe.dateUpdated)
        XCTAssertNotNil(recipe.createdAt)
        XCTAssertNotNil(recipe.updatedAt)
    }

    // MARK: - Multiple JSON-LD Blocks

    func testFindsRecipeAmongMultipleJSONLDBlocks() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Organization", "name": "Food Blog"}
        </script>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Found It", "recipeIngredient": ["salt"]}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Found It")
    }

    // MARK: - HTML Entity Decoding

    func testDecodesHTMLEntitiesInIngredients() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Test",
            "recipeIngredient": [
                "&frac14; cup raw pepitas",
                "2 medium red beets (we&#8217;ll use them raw)",
                "&#8532; cup (2 &frac12; ounces) crumbled feta",
                "Homemade vinaigrette (about &frac14; cup)"
            ]
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeIngredient?[0].display, "¼ cup raw pepitas")
        XCTAssertEqual(recipe.recipeIngredient?[1].display, "2 medium red beets (we\u{2019}ll use them raw)")
        XCTAssertEqual(recipe.recipeIngredient?[2].display, "⅔ cup (2 ½ ounces) crumbled feta")
        XCTAssertEqual(recipe.recipeIngredient?[3].display, "Homemade vinaigrette (about ¼ cup)")
    }

    func testDecodesHTMLEntitiesInInstructions() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Test",
            "recipeInstructions": [
                {"@type": "HowToStep", "text": "Don&#8217;t overcook the pasta &mdash; it should be al dente."}
            ]
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.recipeInstructions?[0].text, "Don\u{2019}t overcook the pasta — it should be al dente.")
    }

    // MARK: - Script Tag Variations

    func testParsesScriptTagWithExtraAttributes() throws {
        let html = """
        <html><head>
        <script type="application/ld+json" id="schema-org" class="yoast-schema-graph">
        {"@type": "Recipe", "name": "Extra Attrs Recipe"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Extra Attrs Recipe")
    }

    func testParsesScriptTagWithSingleQuotes() throws {
        let html = """
        <html><head>
        <script type='application/ld+json'>
        {"@type": "Recipe", "name": "Single Quotes"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Single Quotes")
    }

    func testParsesScriptTagWithWhitespace() throws {
        let html = """
        <html><head>
        <script  type="application/ld+json" >
        {"@type": "Recipe", "name": "Whitespace Tag"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Whitespace Tag")
    }

    // MARK: - Real-world Site Structure (cookieandkate.com style)

    func testParsesRecipeFromGraphWithMultipleTypes() throws {
        let html = """
        <html><head>
        <script type="application/ld+json" class="yoast-schema-graph">
        {
            "@context": "https://schema.org",
            "@graph": [
                {"@type": "WebSite", "name": "Cookie and Kate"},
                {"@type": "WebPage", "name": "Beet Salad"},
                {"@type": "Article", "name": "Beet Salad Post"},
                {
                    "@type": "Recipe",
                    "name": "Simple Beet, Arugula and Feta Salad",
                    "description": "Features raw beets and balsamic dressing",
                    "prepTime": "PT15M",
                    "cookTime": "PT5M",
                    "totalTime": "PT20M",
                    "recipeYield": ["4", "4 salads"],
                    "recipeCategory": "Salad",
                    "recipeIngredient": [
                        "3 medium beets, peeled",
                        "5 oz arugula",
                        "1/3 cup crumbled feta"
                    ],
                    "recipeInstructions": [
                        {"@type": "HowToStep", "text": "Peel and grate the beets."},
                        {"@type": "HowToStep", "text": "Toss with arugula and dressing."},
                        {"@type": "HowToStep", "text": "Top with feta and pepitas."}
                    ],
                    "nutrition": {
                        "@type": "NutritionInformation",
                        "calories": "195 calories",
                        "carbohydrateContent": "9.6 g",
                        "proteinContent": "5.4 g",
                        "fatContent": "15.6 g"
                    },
                    "image": ["https://example.com/beet-salad.jpg"]
                },
                {"@type": "Person", "name": "Kate"}
            ]
        }
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://cookieandkate.com/beet-salad")
        XCTAssertEqual(recipe.name, "Simple Beet, Arugula and Feta Salad")
        XCTAssertEqual(recipe.description, "Features raw beets and balsamic dressing")
        XCTAssertEqual(recipe.prepTime, "PT15M")
        XCTAssertEqual(recipe.performTime, "PT5M")
        XCTAssertEqual(recipe.totalTime, "PT20M")
        XCTAssertEqual(recipe.recipeYield, "4")
        XCTAssertEqual(recipe.recipeIngredient?.count, 3)
        XCTAssertEqual(recipe.recipeInstructions?.count, 3)
        XCTAssertEqual(recipe.nutrition?.calories, "195 calories")
        XCTAssertEqual(recipe.nutrition?.proteinContent, "5.4 g")
        XCTAssertEqual(recipe.recipeCategory?.count, 1)
        XCTAssertEqual(recipe.recipeCategory?.first?.name, "Salad")
        XCTAssertEqual(recipe.orgURL, "https://cookieandkate.com/beet-salad")
    }

    // MARK: - Minimal Recipe

    func testParsesMinimalRecipe() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type": "Recipe", "name": "Just a Name"}
        </script>
        </head><body></body></html>
        """

        let recipe = try parser.parseRecipeFromHTML(html, sourceURL: "https://example.com")
        XCTAssertEqual(recipe.name, "Just a Name")
        XCTAssertNil(recipe.recipeIngredient)
        XCTAssertNil(recipe.recipeInstructions)
        XCTAssertNil(recipe.nutrition)
        XCTAssertNil(recipe.prepTime)
        XCTAssertNil(recipe.performTime)
        XCTAssertNil(recipe.totalTime)
    }
}
