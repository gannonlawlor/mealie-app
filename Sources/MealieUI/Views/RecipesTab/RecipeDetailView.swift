import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct RecipeDetailView: View {
    @Bindable var recipeVM: RecipeViewModel
    let slug: String
    @State var showDeleteAlert = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if recipeVM.isLoadingDetail {
                ProgressView("Loading recipe...")
            } else if let recipe = recipeVM.selectedRecipe {
                recipeContent(recipe)
            } else {
                Text("Recipe not found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(recipeVM.selectedRecipe?.name ?? "Recipe")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Recipe", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await recipeVM.deleteRecipe(slug: slug)
                    if success { dismiss() }
                }
            }
        } message: {
            Text("Are you sure you want to delete this recipe? This cannot be undone.")
        }
        .task {
            await recipeVM.loadRecipeDetail(slug: slug)
        }
    }

    func recipeContent(_ recipe: Recipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero Image
                if let recipeId = recipe.id {
                    AsyncImage(url: URL(string: MealieAPI.shared.recipeImageURL(recipeId: recipeId))) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(white: 0.85))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Description
                if let description = recipe.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Time & Yield Info
                timeInfoSection(recipe)

                // Categories & Tags
                tagsSection(recipe)

                // Ingredients
                if let ingredients = recipe.recipeIngredient, !ingredients.isEmpty {
                    ingredientsSection(ingredients)
                }

                // Instructions
                if let instructions = recipe.recipeInstructions, !instructions.isEmpty {
                    instructionsSection(instructions)
                }

                // Nutrition
                if let nutrition = recipe.nutrition {
                    nutritionSection(nutrition)
                }

                Spacer().frame(height: 32)
            }
        }
    }

    func timeInfoSection(_ recipe: Recipe) -> some View {
        let items: [(String, String)] = [
            ("Prep", recipe.prepTime ?? ""),
            ("Cook", recipe.performTime ?? ""),
            ("Total", recipe.totalTime ?? ""),
            ("Yield", recipe.recipeYield ?? ""),
        ].filter { !$0.1.isEmpty }

        return Group {
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 4) {
                                Text(item.0)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatDuration(item.1))
                                    .font(.subheadline)
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.9))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    func tagsSection(_ recipe: Recipe) -> some View {
        let allTags: [(String, String)] =
            (recipe.recipeCategory ?? []).map { ("folder", $0.name ?? "") } +
            (recipe.tags ?? []).map { ("tag", $0.name ?? "") }

        return Group {
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(allTags.enumerated()), id: \.offset) { _, tag in
                            Label(tag.1, systemImage: tag.0)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    func ingredientsSection(_ ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ingredients) { ingredient in
                    if let title = ingredient.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .bold()
                            .padding(.top, 4)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 6))
                            .padding(.top, 6)
                            .foregroundStyle(.secondary)
                        Text(ingredient.displayText)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    func instructionsSection(_ instructions: [RecipeInstruction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = instruction.title, !title.isEmpty {
                            Text(title)
                                .font(.headline)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            Text(instruction.text ?? "")
                                .font(.body)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    func nutritionSection(_ nutrition: Nutrition) -> some View {
        let items: [(String, String)] = [
            ("Calories", nutrition.calories ?? ""),
            ("Fat", nutrition.fatContent ?? ""),
            ("Protein", nutrition.proteinContent ?? ""),
            ("Carbs", nutrition.carbohydrateContent ?? ""),
            ("Fiber", nutrition.fiberContent ?? ""),
            ("Sugar", nutrition.sugarContent ?? ""),
        ].filter { !$0.1.isEmpty }

        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 4) {
                                Text(item.1)
                                    .font(.subheadline)
                                    .bold()
                                Text(item.0)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color(white: 0.9))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    func formatDuration(_ iso: String) -> String {
        // Simple ISO 8601 duration parser (PT1H30M -> 1h 30m)
        var result = iso
            .replacingOccurrences(of: "PT", with: "")
            .replacingOccurrences(of: "H", with: "h ")
            .replacingOccurrences(of: "M", with: "m ")
            .replacingOccurrences(of: "S", with: "s")
            .trimmingCharacters(in: .whitespaces)
        if !result.contains("h") && !result.contains("m") && !result.contains("s") {
            result = iso // If not ISO format, return as-is
        }
        return result
    }
}
