import PDFKit
import XCTest
@testable import MealieModel
@testable import MealieUI

@MainActor
final class RecipePDFTests: XCTestCase {
    func testOriginalRecipeHasClickableLinkNearTopOfPDF() throws {
        let url = "https://example.com/recipes/soup?servings=4&unit=metric"
        let data = try JSONSerialization.data(withJSONObject: ["name": "Soup", "orgURL": url,
            "description": "A cozy soup.", "recipeIngredient": [["display": "2 cups rice"]]])
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        let pdf = try XCTUnwrap(PDFDocument(data: RecipePDFRenderer.data(for: recipe)))
        let page = try XCTUnwrap(pdf.page(at: 0))
        let annotation = try XCTUnwrap(page.annotations.first { $0.url?.absoluteString == url })
        XCTAssertEqual(annotation.type, "Link")
        XCTAssertGreaterThan(annotation.bounds.minY, page.bounds(for: .mediaBox).height * 0.75)
        let label = try XCTUnwrap(pdf.findString("Original recipe: example.com", withOptions: []).first)
        XCTAssertTrue(annotation.bounds.intersects(label.bounds(for: page)))
        let text = try XCTUnwrap(page.string)
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "Original recipe:")).lowerBound,
                          try XCTUnwrap(text.range(of: "A cozy soup.")).lowerBound)
    }

    func testSharingCreatesUniqueNamedPDFWithRecipeContents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data("""
        {"name":"Soup / family: recipe","recipeIngredient":[{"display":"2 cups rice"}],"recipeInstructions":[{"text":"Stir until cooked."}]}
        """.utf8))
        let first = try RecipePDFFile.create(for: recipe, directory: root)
        let second = try RecipePDFFile.create(for: recipe, directory: root)
        XCTAssertNotEqual(first.url, second.url)
        XCTAssertEqual(first.url.lastPathComponent, "Soup _ family_ recipe.pdf")
        let document = try XCTUnwrap(PDFDocument(url: first.url))
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("2 cups rice"))
        XCTAssertTrue(text.contains("Stir until cooked."))
        XCTAssertNotNil(PDFDocument(url: second.url))
    }

    func testSharePreparationReportsStorageFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data("{\"name\":\"Soup\"}".utf8))
        XCTAssertThrowsError(try RecipePDFFile.create(for: recipe, directory: root))
    }

    func testLongRecipeProducesReadableMultiplePages() throws {
        let steps = (1...70).map { ["text": "Instruction \($0): " + String(repeating: "Stir gently and check the texture. ", count: 8)] }
        let data = try JSONSerialization.data(withJSONObject: ["name": "Soup for a crowd", "description": "A printable recipe with complete instructions.",
            "recipeYield": "12 servings", "prepTime": "PT15M", "recipeIngredient": [["display": "2 cups rice"], ["display": "1 tablespoon fresh parsley"]],
            "recipeInstructions": steps, "orgURL": "https://example.com/recipes/soup?servings=12&unit=metric"])
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        let pdf = RecipePDFRenderer.data(for: recipe)
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("Soup for a crowd"))
        XCTAssertTrue(text.contains("2 cups rice"))
        XCTAssertTrue(text.contains("Instruction 70:"))
        // Disposable rendering evidence for review, outside the repository.
        try pdf.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("recipe-print-preview.pdf"))
        let first = try XCTUnwrap(document.page(at: 0))
        let image = first.thumbnail(of: CGSize(width: 816, height: 1056), for: .mediaBox)
        try XCTUnwrap(image.pngData()).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("recipe-print-preview.png"))
    }
}
