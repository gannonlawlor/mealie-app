import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
import PhotosUI
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
    @State var selectedCategoryIds: Set<String> = []
    @State var selectedTagIds: Set<String> = []
    @State var isSaving = false
    @State var selectedImageData: Data? = nil
    @State var selectedImageURL: URL? = nil
    #if !os(Android)
    @State var selectedPhoto: PhotosPickerItem? = nil
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    if let url = selectedImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(8)
                    } else if let recipeId = recipe.id {
                        AsyncImage(url: currentImageURL(recipeId: recipeId)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(8)
                    }

                    #if !os(Android)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Change Image", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            guard let item = newValue else { return }
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                // Save to temp file for preview
                                let tempDir = FileManager.default.temporaryDirectory
                                let tempFile = tempDir.appendingPathComponent("recipe_preview_\(UUID().uuidString).jpg")
                                try? data.write(to: tempFile)
                                selectedImageURL = tempFile
                            }
                        }
                    }
                    #endif
                }

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

                if !recipeVM.categories.isEmpty {
                    Section("Categories") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipeVM.categories) { cat in
                                    if let catId = cat.id {
                                        Button(action: {
                                            if selectedCategoryIds.contains(catId) {
                                                selectedCategoryIds.remove(catId)
                                            } else {
                                                selectedCategoryIds.insert(catId)
                                            }
                                        }) {
                                            Text(cat.name ?? "")
                                                .font(.subheadline)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(selectedCategoryIds.contains(catId) ? Color.accentColor : Color.accentColor.opacity(0.12))
                                                .foregroundStyle(selectedCategoryIds.contains(catId) ? .white : Color.accentColor)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if !recipeVM.tags.isEmpty {
                    Section("Tags") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipeVM.tags) { tag in
                                    if let tagId = tag.id {
                                        Button(action: {
                                            if selectedTagIds.contains(tagId) {
                                                selectedTagIds.remove(tagId)
                                            } else {
                                                selectedTagIds.insert(tagId)
                                            }
                                        }) {
                                            Text(tag.name ?? "")
                                                .font(.subheadline)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(selectedTagIds.contains(tagId) ? Color.accentColor : Color.accentColor.opacity(0.12))
                                                .foregroundStyle(selectedTagIds.contains(tagId) ? .white : Color.accentColor)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }
                    }
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

    func currentImageURL(recipeId: String) -> URL? {
        if recipeVM.isLocalMode {
            if let path = LocalRecipeStore.shared.imageFilePath(recipeId: recipeId) {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        if let cachedPath = ImageCacheService.shared.cachedImagePath(recipeId: recipeId, imageType: "min-original.webp") {
            return URL(fileURLWithPath: cachedPath)
        }
        return URL(string: MealieAPI.shared.recipeImageURL(recipeId: recipeId))
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
        if let cats = recipe.recipeCategory {
            selectedCategoryIds = Set(cats.compactMap { $0.id })
        }
        if let recipeTags = recipe.tags {
            selectedTagIds = Set(recipeTags.compactMap { $0.id })
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

        let selectedCategories = recipeVM.categories.filter { selectedCategoryIds.contains($0.id ?? "") }
        let selectedTags = recipeVM.tags.filter { selectedTagIds.contains($0.id ?? "") }

        let updated = Recipe(
            id: recipe.id,
            slug: recipe.slug,
            name: name,
            description: description.isEmpty ? nil : description,
            image: recipe.image,
            recipeCategory: selectedCategories.isEmpty ? nil : selectedCategories,
            tags: selectedTags.isEmpty ? nil : selectedTags,
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

        // Upload image if user selected a new one
        if success, let imageData = selectedImageData {
            let uploadSlug = recipeVM.selectedRecipe?.slug ?? recipe.slug ?? ""
            let _ = await recipeVM.uploadImage(slug: uploadSlug, imageData: imageData)
        }

        isSaving = false
        if success {
            isPresented = false
        }
    }
}
