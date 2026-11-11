import XCTest
@testable import MealieModel

final class RecipePrintDocumentTests: XCTestCase {
    func testPrintUsesDisplayedContentAndEscapesMarkup() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(#"{"name":"Soup & <script>bad()</script>","description":"Line one\nLine two","recipeYield":"4 servings","prepTime":"PT15M","recipeIngredient":[{"title":"Sauce","quantity":2,"unit":{"name":"cups"},"food":{"name":"rice"}}],"recipeInstructions":[{"title":"Finish","text":"Mix <gently> & serve."}],"nutrition":{"calories":"200"},"orgURL":"https://example.test/?a=1&b=2"}"#.utf8))
        let html = RecipePrintDocument.html(for: recipe)
        XCTAssertFalse(html.contains("<script>"))
        for expected in ["Soup &amp; &lt;script&gt;", "Line one\nLine two", "4 servings", "15m", "2 cups rice",
                         "<h3>Sauce</h3>", "<h3>Finish</h3>", "Mix &lt;gently&gt; &amp; serve.", "200", "?a=1&amp;b=2"] {
            XCTAssertTrue(html.contains(expected), expected)
        }
    }

    func testEmptyRecipeOmitsMissingSections() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data("{}".utf8))
        let html = RecipePrintDocument.html(for: recipe)
        XCTAssertTrue(html.contains("<h1>Recipe</h1>"))
        XCTAssertFalse(html.contains("<h2>"))
        XCTAssertFalse(html.contains("nil"))
    }
}
