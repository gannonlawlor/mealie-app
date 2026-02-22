import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct RecipeSplitView: View {
    @Bindable var recipeVM: RecipeViewModel
    @State var selectedSlug: String? = nil
    @State var showImportSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: recipe list
            NavigationStack {
                recipeListColumn
                    .navigationTitle("Recipes")
                    .searchable(text: $recipeVM.searchText, prompt: "Search recipes...")
                    .onSubmit(of: .search) {
                        Task { await recipeVM.search() }
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
            }
            .frame(width: 340)

            Divider()

            // Right: detail
            NavigationStack {
                if let slug = selectedSlug {
                    RecipeDetailView(
                        recipeVM: recipeVM,
                        slug: slug,
                        onDelete: { selectedSlug = nil }
                    )
                    .id(slug)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a recipe")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            if recipeVM.recipes.isEmpty {
                await recipeVM.loadRecipes(reset: true)
                await recipeVM.loadCategories()
                await recipeVM.loadTags()
            }
        }
    }

    var recipeListColumn: some View {
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
                    Button(action: {
                        selectedSlug = recipe.slug
                    }) {
                        RecipeRowView(recipe: recipe, isLocalMode: recipeVM.isLocalMode)
                    }
                    .listRowBackground(
                        selectedSlug == recipe.slug
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
                .onDelete { offsets in
                    Task {
                        for index in offsets {
                            let slug = recipeVM.recipes[index].slug
                            if slug == selectedSlug {
                                selectedSlug = nil
                            }
                            if let slug = slug {
                                await recipeVM.deleteRecipe(slug: slug)
                            }
                        }
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
        .refreshable {
            await recipeVM.loadRecipes(reset: true)
        }
    }
}
