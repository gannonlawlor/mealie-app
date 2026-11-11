import SnapshotTesting
import SwiftUI
import XCTest
@testable import MealieModel
@testable import MealieUI

@MainActor
final class MediumPriorityUITests: XCTestCase {
    private func recipe() throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: Data(#"{"id":"draft","slug":"soup","name":"Soup"}"#.utf8))
    }

    func testEditorTracksUnsavedTextAndImageForDismissalProtection() throws {
        let recipe = try recipe()
        let unchanged = EditRecipeView(recipeVM: RecipeViewModel(), recipe: recipe,
            isPresented: .constant(true), name: "Soup")
        XCTAssertFalse(unchanged.hasUnsavedChanges)
        let edited = EditRecipeView(recipeVM: RecipeViewModel(), recipe: recipe,
            isPresented: .constant(true), name: "Soup", description: "Unsaved description")
        XCTAssertTrue(edited.hasUnsavedChanges)
        let image = EditRecipeView(recipeVM: RecipeViewModel(), recipe: recipe,
            isPresented: .constant(true), name: "Soup", selectedImageData: Data([1]))
        XCTAssertTrue(image.hasUnsavedChanges)
    }

    func testIngredientShoppingControlsAtLargeText() throws {
        let ingredients = try JSONDecoder().decode([RecipeIngredient].self, from:
            Data(#"[{"note":"2 cups rice"},{"note":"1 tablespoon finely chopped fresh parsley"}]"#.utf8))
        let vm = RecipeViewModel()
        vm.isLocalMode = false
        let detail = RecipeDetailView(recipeVM: vm, shoppingVM: ShoppingViewModel(),
            mealPlanVM: MealPlanViewModel(), slug: "soup")
        assertSnapshot(of: detail.ingredientsSection(ingredients).padding().background(Color.white)
            .environment(\.dynamicTypeSize, .accessibility1),
            as: .image(layout: .fixed(width: 390, height: 400)))
    }

    func testLocalIngredientsDoNotOfferServerShoppingActions() throws {
        let ingredients = try JSONDecoder().decode([RecipeIngredient].self, from: Data(#"[{"note":"2 cups rice"}]"#.utf8))
        let vm = RecipeViewModel()
        vm.isLocalMode = true
        let detail = RecipeDetailView(recipeVM: vm, shoppingVM: ShoppingViewModel(),
            mealPlanVM: MealPlanViewModel(), slug: "soup")
        assertSnapshot(of: detail.ingredientsSection(ingredients).padding().background(Color.white),
            as: .image(layout: .fixed(width: 390, height: 180)))
    }
}
