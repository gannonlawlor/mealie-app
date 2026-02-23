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
                VStack(spacing: 0) {
                    if !recipeVM.categories.isEmpty || !recipeVM.tags.isEmpty {
                        filterChips
                    }
                    recipeListColumn
                }
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

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recipeVM.categories) { cat in
                    Button(action: {
                        if recipeVM.selectedCategory?.id == cat.id {
                            recipeVM.selectedCategory = nil
                        } else {
                            recipeVM.selectedCategory = cat
                        }
                        Task { await recipeVM.loadRecipes(reset: true) }
                    }) {
                        Label(cat.name ?? "", systemImage: "folder")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(recipeVM.selectedCategory?.id == cat.id ? Color.accentColor : Color.accentColor.opacity(0.12))
                            .foregroundStyle(recipeVM.selectedCategory?.id == cat.id ? .white : Color.accentColor)
                            .cornerRadius(16)
                    }
                }
                ForEach(recipeVM.tags) { tag in
                    Button(action: {
                        if recipeVM.selectedTag?.id == tag.id {
                            recipeVM.selectedTag = nil
                        } else {
                            recipeVM.selectedTag = tag
                        }
                        Task { await recipeVM.loadRecipes(reset: true) }
                    }) {
                        Label(tag.name ?? "", systemImage: "tag")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(recipeVM.selectedTag?.id == tag.id ? Color.accentColor : Color.accentColor.opacity(0.12))
                            .foregroundStyle(recipeVM.selectedTag?.id == tag.id ? .white : Color.accentColor)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
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
                        RecipeRowView(
                            recipe: recipe,
                            isLocalMode: recipeVM.isLocalMode,
                            isSavedOffline: !recipeVM.isLocalMode && recipeVM.isOffline(recipeId: recipe.id ?? "")
                        )
                    }
                    .listRowBackground(
                        selectedSlug == recipe.slug
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                    .swipeActions(edge: .leading) {
                        if let slug = recipe.slug {
                            Button {
                                let userId = AuthService.shared.savedUserId ?? ""
                                Task { await recipeVM.toggleFavorite(slug: slug, userId: userId) }
                            } label: {
                                Image(systemName: recipeVM.isFavorite(slug: slug) ? "heart.slash" : "heart")
                            }
                            .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if let slug = recipe.slug {
                            Button(role: .destructive) {
                                Task {
                                    if slug == selectedSlug { selectedSlug = nil }
                                    await recipeVM.deleteRecipe(slug: slug)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }

                            if !recipeVM.isLocalMode, let recipeId = recipe.id {
                                Button {
                                    Task { await recipeVM.toggleOffline(slug: slug, recipeId: recipeId) }
                                } label: {
                                    Image(systemName: recipeVM.isOffline(recipeId: recipeId) ? "trash.circle" : "arrow.down.circle")
                                }
                                .tint(recipeVM.isOffline(recipeId: recipeId) ? .red : .blue)
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
