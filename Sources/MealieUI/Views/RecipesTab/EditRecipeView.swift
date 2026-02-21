import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct EditRecipeView: View {
    @Bindable var recipeVM: RecipeViewModel
    let recipe: Recipe
    @Binding var isPresented: Bool

    @State var name: String = ""
    @State var description: String = ""
    @State var recipeYield: String = ""
    @State var prepTime: String = ""
    @State var performTime: String = ""
    @State var totalTime: String = ""
    @State var ingredientTexts: [String] = []
    @State var instructionTexts: [String] = []
    @State var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Yield (e.g. 4 servings)", text: $recipeYield)
                }

                Section("Times") {
                    TextField("Prep Time", text: $prepTime)
                    TextField("Cook Time", text: $performTime)
                    TextField("Total Time", text: $totalTime)
                }

                Section("Ingredients") {
                    ForEach(Array(ingredientTexts.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            TextField("Ingredient", text: $ingredientTexts[index])
                            Button(action: { ingredientTexts.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Button(action: { ingredientTexts.append("") }) {
                        Label("Add Ingredient", systemImage: "plus")
                    }
                }

                Section("Instructions") {
                    ForEach(Array(instructionTexts.enumerated()), id: \.offset) { index, _ in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            TextField("Step", text: $instructionTexts[index])
                            Button(action: { instructionTexts.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Button(action: { instructionTexts.append("") }) {
                        Label("Add Step", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit Recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .task {
                populateFields()
            }
        }
    }

    func populateFields() {
        name = recipe.name ?? ""
        description = recipe.description ?? ""
        recipeYield = recipe.recipeYield ?? ""
        prepTime = recipe.prepTime ?? ""
        performTime = recipe.performTime ?? ""
        totalTime = recipe.totalTime ?? ""

        if let ingredients = recipe.recipeIngredient {
            ingredientTexts = ingredients.map { $0.displayText }
        }
        if let instructions = recipe.recipeInstructions {
            instructionTexts = instructions.map { $0.text ?? "" }
        }
    }

    func save() async {
        isSaving = true

        let ingredients = ingredientTexts.filter { !$0.isEmpty }.map { text in
            RecipeIngredient(
                quantity: nil, unit: nil, food: nil,
                note: text, isFood: false, disableAmount: true,
                display: text, title: nil, originalText: text, referenceId: nil
            )
        }

        let instructions = instructionTexts.filter { !$0.isEmpty }.enumerated().map { index, text in
            RecipeInstruction(
                id: nil, title: nil, text: text, ingredientReferences: nil
            )
        }

        let updated = Recipe(
            id: recipe.id,
            slug: recipe.slug,
            name: name,
            description: description.isEmpty ? nil : description,
            image: recipe.image,
            recipeCategory: recipe.recipeCategory,
            tags: recipe.tags,
            tools: recipe.tools,
            rating: recipe.rating,
            recipeYield: recipeYield.isEmpty ? nil : recipeYield,
            recipeIngredient: ingredients,
            recipeInstructions: instructions,
            totalTime: totalTime.isEmpty ? nil : totalTime,
            prepTime: prepTime.isEmpty ? nil : prepTime,
            performTime: performTime.isEmpty ? nil : performTime,
            nutrition: recipe.nutrition,
            settings: recipe.settings,
            dateAdded: recipe.dateAdded,
            dateUpdated: recipe.dateUpdated,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            orgURL: recipe.orgURL,
            extras: recipe.extras
        )

        let success = await recipeVM.updateRecipe(slug: recipe.slug ?? "", data: updated)
        isSaving = false
        if success {
            isPresented = false
        }
    }
}
