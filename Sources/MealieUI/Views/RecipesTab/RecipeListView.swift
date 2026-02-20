import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct RecipeListView: View {
    @Bindable var recipeVM: RecipeViewModel
    @State var showImportSheet = false

    var body: some View {
        List {
            if recipeVM.isLoading && recipeVM.recipes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if recipeVM.recipes.isEmpty {
                Text("No recipes found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(recipeVM.recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRowView(recipe: recipe)
                    }
                }

                if recipeVM.currentPage < recipeVM.totalPages {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .task {
                        await recipeVM.loadNextPage()
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeVM: recipeVM, slug: recipe.slug ?? "")
        }
        .searchable(text: $recipeVM.searchText, prompt: "Search recipes...")
        .onSubmit(of: .search) {
            Task { await recipeVM.search() }
        }
        .refreshable {
            await recipeVM.loadRecipes(reset: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showImportSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportRecipeView(recipeVM: recipeVM, isPresented: $showImportSheet)
        }
        .task {
            if recipeVM.recipes.isEmpty {
                await recipeVM.loadRecipes(reset: true)
                await recipeVM.loadCategories()
                await recipeVM.loadTags()
            }
        }
    }
}

struct RecipeRowView: View {
    let recipe: RecipeSummary

    var body: some View {
        HStack(spacing: 12) {
            if let recipeId = recipe.id {
                AsyncImage(url: URL(string: MealieAPI.shared.recipeImageURL(recipeId: recipeId, imageType: "tiny-original.webp"))) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name ?? "Untitled")
                    .font(.headline)
                    .lineLimit(2)

                if let description = recipe.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let categories = recipe.recipeCategory, !categories.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(categories.prefix(3)) { cat in
                            Text(cat.name ?? "")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            if let rating = recipe.rating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(rating)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ImportRecipeView: View {
    @Bindable var recipeVM: RecipeViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Import a Recipe")
                    .font(.headline)

                Text("Paste a URL from a recipe website and Mealie will automatically import it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Recipe URL", text: $recipeVM.importURL)
                    .autocorrectionDisabled()

                    .padding()
                    .background(Color(white: 0.9))
                    .cornerRadius(10)

                Button(action: {
                    Task {
                        await recipeVM.importFromURL()
                        if recipeVM.importMessage.contains("successfully") {
                            isPresented = false
                        }
                    }
                }) {
                    if recipeVM.isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Import Recipe")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .foregroundStyle(.white)
                .background(recipeVM.importURL.isEmpty ? Color.gray : Color.accentColor)
                .cornerRadius(10)
                .disabled(recipeVM.importURL.isEmpty || recipeVM.isImporting)

                if !recipeVM.importMessage.isEmpty {
                    Text(recipeVM.importMessage)
                        .font(.caption)
                        .foregroundStyle(recipeVM.importMessage.contains("successfully") ? .green : .red)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
