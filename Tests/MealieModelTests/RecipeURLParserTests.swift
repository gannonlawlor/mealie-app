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
