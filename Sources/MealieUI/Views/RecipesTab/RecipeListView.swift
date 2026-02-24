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
    @State var showFavoritesOnly: Bool = false

    var displayedRecipes: [RecipeSummary] {
        if showFavoritesOnly {
            return recipeVM.recipes.filter { recipeVM.isFavorite(slug: $0.slug ?? "") }
        }
        return recipeVM.recipes
    }

    var body: some View {
        VStack(spacing: 0) {
            if !recipeVM.errorMessage.isEmpty {
                ErrorBanner(message: recipeVM.errorMessage) {
                    recipeVM.errorMessage = ""
                }
                .padding(.top, 4)
            }
            #if os(Android)
            if !recipeVM.categories.isEmpty || !recipeVM.tags.isEmpty {
                filterChips
            }
            #else
            activeFilterChip
            #endif
            recipeList
        }
        .navigationTitle("Recipes")
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeVM: recipeVM, slug: recipe.slug ?? "")
        }
        .searchable(text: $recipeVM.searchText, prompt: "Search recipes...")
        #if !os(Android)
        .searchSuggestions {
            if recipeVM.searchText.isEmpty || !filteredCategories.isEmpty || !filteredTags.isEmpty {
                if !filteredCategories.isEmpty {
                    Section("Categories") {
                        ForEach(filteredCategories) { cat in
                            Button(action: {
                                recipeVM.selectedCategory = cat
                                recipeVM.searchText = ""
                                Task { await recipeVM.loadRecipes(reset: true) }
                            }) {
                                Label(cat.name ?? "", systemImage: "folder")
                            }
                        }
                    }
                }
                if !filteredTags.isEmpty {
                    Section("Tags") {
                        ForEach(filteredTags) { tag in
                            Button(action: {
                                recipeVM.selectedTag = tag
                                recipeVM.searchText = ""
                                Task { await recipeVM.loadRecipes(reset: true) }
                            }) {
                                Label(tag.name ?? "", systemImage: "tag")
                            }
                        }
                    }
                }
            }
        }
        #endif
        .onSubmit(of: .search) {
            Task { await recipeVM.search() }
        }
        .refreshable {
            await recipeVM.loadRecipes(reset: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: { showFavoritesOnly.toggle() }) {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(showFavoritesOnly ? Color.accentColor : .primary)
                    }
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "plus")
                    }
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

    #if !os(Android)
    var filteredCategories: [RecipeCategory] {
        if recipeVM.searchText.isEmpty { return recipeVM.categories }
        let query = recipeVM.searchText.lowercased()
        return recipeVM.categories.filter { ($0.name ?? "").lowercased().contains(query) }
    }

    var filteredTags: [RecipeTag] {
        if recipeVM.searchText.isEmpty { return recipeVM.tags }
        let query = recipeVM.searchText.lowercased()
        return recipeVM.tags.filter { ($0.name ?? "").lowercased().contains(query) }
    }

    var activeFilterChip: some View {
        Group {
            if let cat = recipeVM.selectedCategory {
                HStack {
                    Button(action: {
                        recipeVM.selectedCategory = nil
                        Task { await recipeVM.loadRecipes(reset: true) }
                    }) {
                        Label(cat.name ?? "", systemImage: "folder")
                            .font(.subheadline)
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(16)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            } else if let tag = recipeVM.selectedTag {
                HStack {
                    Button(action: {
                        recipeVM.selectedTag = nil
                        Task { await recipeVM.loadRecipes(reset: true) }
                    }) {
                        Label(tag.name ?? "", systemImage: "tag")
                            .font(.subheadline)
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(16)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
    #endif

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

    var recipeList: some View {
        List {
            if recipeVM.isLoading && recipeVM.recipes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if displayedRecipes.isEmpty {
                Text(showFavoritesOnly ? "No favorite recipes" : "No recipes found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(displayedRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRowView(
                            recipe: recipe,
                            isLocalMode: recipeVM.isLocalMode,
                            isSavedOffline: !recipeVM.isLocalMode && recipeVM.isOffline(recipeId: recipe.id ?? "")
                        )
                    }
                    #if !os(Android)
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
                                Task { await recipeVM.deleteRecipe(slug: slug) }
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
                    #endif
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
    }
}

struct RecipeRowView: View {
    let recipe: RecipeSummary
    var isLocalMode: Bool = false
    var isSavedOffline: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let recipeId = recipe.id {
                if isLocalMode, let path = LocalRecipeStore.shared.imageFilePath(recipeId: recipeId) {
                    AsyncImage(url: URL(fileURLWithPath: path)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if !isLocalMode {
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
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)
                }
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

            if isSavedOffline {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

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
    @Environment(\.colorScheme) var colorScheme
    @State var newRecipeName: String = ""
    @State var showCreateForm: Bool = false
    @State var createdRecipe: Recipe? = nil
    @State var showEditSheet: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Import a Recipe")
                    .font(.headline)

                if recipeVM.isLocalMode {
                    Text("Paste a URL and the recipe will be parsed and saved locally.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Paste a URL from a recipe website and Mealie will automatically import it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Recipe URL", text: $recipeVM.importURL)
                    .autocorrectionDisabled()

                    .padding()
                    .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                    .cornerRadius(10)

                Button(action: {
                    Task {
                        await recipeVM.importFromURL()
                        if recipeVM.importMessage.contains("successfully") && !recipeVM.showDuplicateAlert {
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

                if recipeVM.isLocalMode {
                    // Divider with "or"
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    if showCreateForm {
                        TextField("Recipe Name", text: $newRecipeName)
                            .padding()
                            .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                            .cornerRadius(10)

                        Button(action: {
                            Task {
                                let recipe = await recipeVM.createLocalRecipe(name: newRecipeName)
                                createdRecipe = recipe
                                showEditSheet = true
                            }
                        }) {
                            Text("Create Recipe")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .foregroundStyle(.white)
                        .background(newRecipeName.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(10)
                        .disabled(newRecipeName.isEmpty)
                    } else {
                        Button(action: { showCreateForm = true }) {
                            Label("Create New Recipe", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .foregroundStyle(Color.accentColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle(recipeVM.isLocalMode ? "Add Recipe" : "Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let recipe = createdRecipe {
                    EditRecipeView(recipeVM: recipeVM, recipe: recipe, isPresented: $showEditSheet)
                }
            }
            .onChange(of: showEditSheet) { _, newValue in
                if !newValue {
                    // Close import sheet after edit is dismissed
                    isPresented = false
                }
            }
            .alert("Recipe Already Exists", isPresented: $recipeVM.showDuplicateAlert) {
                Button("Update Existing") {
                    Task {
                        await recipeVM.confirmImportUpdate()
                        isPresented = false
                    }
                }
                Button("Import Anyway") {
                    Task {
                        await recipeVM.confirmImportNew()
                        isPresented = false
                    }
                }
                Button("Cancel", role: .cancel) {
                    recipeVM.clearDuplicateState()
                }
            } message: {
                if let name = recipeVM.duplicateRecipe?.name {
                    if recipeVM.duplicateMatchedByURL {
                        Text("A recipe imported from this URL already exists: \"\(name)\". Would you like to update it or import a new copy?")
                    } else {
                        Text("A recipe with the same name already exists: \"\(name)\". Would you like to update it or import a new copy?")
                    }
                }
            }
        }
    }
}
