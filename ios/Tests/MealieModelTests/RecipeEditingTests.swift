import XCTest
@testable import MealieModel

final class RecipeEditingTests: XCTestCase {
    private func ingredient(_ id: String, title: String? = "Dough") -> RecipeIngredient {
        RecipeIngredient(quantity: 2, unit: IngredientUnit(id: "cup", name: "cup", abbreviation: "c", description: nil),
            food: IngredientFood(id: "flour", name: "flour", description: nil, labelId: "pantry"),
            note: "sifted", isFood: true, disableAmount: false, display: "2 cups flour",
            title: title, originalText: "2 cups flour, sifted", referenceId: id)
    }

    func testUnchangedIngredientsRoundTripAllMetadata() {
        let original = ingredient("flour")
        XCTAssertEqual(IngredientDraft(original).value, original)
    }

    func testDeletingDuplicateTextRowKeepsSurvivingRowsIdentity() {
        let first = ingredient("first"), second = ingredient("second")
        var rows = [IngredientDraft(first), IngredientDraft(second)]
        rows.removeFirst()
        XCTAssertEqual(rows.compactMap(\.value), [second])
    }

    func testEditedIngredientBecomesTextButKeepsSectionAndReference() {
        var row = IngredientDraft(ingredient("flour"))
        row.text = "3 cups flour"
        XCTAssertEqual(row.value?.referenceId, "flour")
        XCTAssertEqual(row.value?.title, "Dough")
        XCTAssertEqual(row.value?.displayText, "3 cups flour")
        XCTAssertNil(row.value?.quantity)
    }

    func testInstructionEditRetainsIdentityTitleAndIngredientReferences() {
        let original = RecipeInstruction(id: "step", title: "Mix", text: "Stir", ingredientReferences: ["flour"])
        var row = InstructionDraft(original)
        XCTAssertEqual(row.value, original)
        row.text = "Whisk"
        XCTAssertEqual(row.value?.id, "step")
        XCTAssertEqual(row.value?.title, "Mix")
        XCTAssertEqual(row.value?.ingredientReferences, ["flour"])
        XCTAssertEqual(row.value?.text, "Whisk")
    }

    func testEmptySectionHeadingIsNotDeletedByUnrelatedEdit() {
        let heading = RecipeInstruction(id: "section", title: "Sauce", text: nil, ingredientReferences: nil)
        XCTAssertEqual(InstructionDraft(heading).value, heading)
        XCTAssertNil(InstructionDraft().value)
    }

    func testUnavailableAssociationsSurviveButVisibleDeselectionIsRespected() {
        let hidden = RecipeTag(id: "hidden", name: "Hidden", slug: "hidden")
        let visible = RecipeTag(id: "visible", name: "Visible", slug: "visible")
        let result = editedAssociations(original: [hidden, visible], available: [visible], selected: Set<String?>())
        XCTAssertEqual(result, [hidden])
    }
}
