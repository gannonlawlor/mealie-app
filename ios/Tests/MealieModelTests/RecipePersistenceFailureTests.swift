import XCTest
import SwiftData
@testable import MealieModel

@MainActor
final class RecipePersistenceFailureTests: XCTestCase {
    private struct DiskFailure: Error {}

    private final class FailingStore: RecipePersistence, @unchecked Sendable {
        func loadAllRecipes() -> [Recipe] { [] }
        func loadRecipe(slug: String) -> Recipe? { nil }
        func saveRecipe(_ recipe: Recipe) throws { throw DiskFailure() }
        func deleteRecipe(id: String) throws { throw DiskFailure() }
        func recipeSummaries() -> [RecipeSummary] { [] }
        func recipeCount() -> Int { 0 }
        func findRecipeByOrgURL(_ url: String) -> Recipe? { nil }
        func findRecipesByName(_ name: String) -> [Recipe] { [] }
        func loadFavorites() -> Set<String> { [] }
        func saveFavorites(_ favorites: Set<String>) throws { throw DiskFailure() }
        func addFavorite(slug: String) throws { throw DiskFailure() }
        func removeFavorite(slug: String) throws { throw DiskFailure() }
    }

    private func recipe(id: String = UUID().uuidString, image: String? = nil) -> Recipe {
        Recipe(id: id, slug: "test", name: "Test", description: nil, image: image,
               recipeCategory: nil, tags: nil, tools: nil, rating: nil, recipeYield: nil,
               recipeIngredient: nil, recipeInstructions: nil, totalTime: nil,
               prepTime: nil, performTime: nil, nutrition: nil, settings: nil,
               dateAdded: nil, dateUpdated: nil, createdAt: nil, updatedAt: nil,
               orgURL: nil, extras: nil)
    }

    func testFailedSavePreservesPendingDuplicateAndImportURL() async {
        let vm = RecipeViewModel(localStore: LocalRecipeStore(store: FailingStore()))
        vm.isLocalMode = true
        vm.pendingImportRecipe = recipe()
        vm.importURL = "https://example.com/recipe"
        await vm.confirmImportNew()
        XCTAssertNotNil(vm.pendingImportRecipe)
        XCTAssertEqual(vm.importURL, "https://example.com/recipe")
        XCTAssertFalse(vm.errorMessage.isEmpty)
        XCTAssertFalse(vm.importMessage.contains("successfully"))
    }

    func testFailedUpdateAndCreateDoNotReportSuccess() async {
        let vm = RecipeViewModel(localStore: LocalRecipeStore(store: FailingStore()))
        vm.isLocalMode = true
        let saved = await vm.updateRecipe(slug: "test", data: recipe())
        XCTAssertFalse(saved)
        XCTAssertNil(vm.selectedRecipe)
        let created = await vm.createLocalRecipe(name: "Unsaved")
        XCTAssertNil(created)
    }

    func testFailedFavoriteDoesNotChangeDisplayedState() async {
        let vm = RecipeViewModel(localStore: LocalRecipeStore(store: FailingStore()))
        vm.isLocalMode = true
        await vm.toggleFavorite(slug: "test", userId: "")
        XCTAssertFalse(vm.isFavorite(slug: "test"))
        XCTAssertFalse(vm.errorMessage.isEmpty)
    }

    func testInitializationFailureIsRecoverableWithoutFallbackStore() throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("existing library".utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }
        var attempts = 0
        let store = LocalRecipeStore(makeStore: {
            attempts += 1
            throw DiskFailure()
        })
        XCTAssertNotNil(store.initializationError)
        XCTAssertThrowsError(try store.saveRecipe(recipe()))
        store.retryOpeningLibrary()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "existing library")
        XCTAssertNotNil(store.initializationError)
    }

    func testImageBytesRecreateDeviceLocalPhotoWithoutOriginalPath() throws {
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let store = try SwiftDataRecipeStore(configuration: config)
        let id = UUID().uuidString
        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bytes = Data([0xff, 0xd8, 0x01, 0x02, 0xff, 0xd9])
        try bytes.write(to: original)
        defer {
            try? FileManager.default.removeItem(at: original)
            if let cached = try? RecipeImageFiles.url(recipeId: id) {
                try? FileManager.default.removeItem(at: cached)
            }
        }
        try store.saveRecipe(recipe(id: id, image: original.path))
        try FileManager.default.removeItem(at: original)
        let loaded = try XCTUnwrap(store.loadRecipe(slug: "test"))
        let path = try XCTUnwrap(loaded.image)
        XCTAssertNotEqual(path, original.path)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), bytes)
        // Simulate a device whose local cache has not been populated yet.
        try FileManager.default.removeItem(atPath: path)
        XCTAssertNotNil(store.loadRecipe(slug: "test")?.image)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), bytes)
    }

    func testRemoteReplacementAndRemovalDoNotRestoreOldEmbeddedPhoto() throws {
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let store = try SwiftDataRecipeStore(configuration: config)
        let id = UUID().uuidString
        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }
        try store.saveRecipe(recipe(id: id, image: original.path))
        try store.saveRecipe(recipe(id: id, image: "https://example.com/new.jpg"))
        XCTAssertEqual(store.loadRecipe(slug: "test")?.image, "https://example.com/new.jpg")
        try store.saveRecipe(recipe(id: id, image: original.path))
        try store.saveRecipe(recipe(id: id, image: nil))
        XCTAssertNil(store.loadRecipe(slug: "test")?.image)
    }

    func testMissingIdentifierThrowsInsteadOfSilentlySucceeding() throws {
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let store = try SwiftDataRecipeStore(configuration: config)
        let invalid = Recipe(id: nil, slug: nil, name: nil, description: nil, image: nil,
            recipeCategory: nil, tags: nil, tools: nil, rating: nil, recipeYield: nil,
            recipeIngredient: nil, recipeInstructions: nil, totalTime: nil,
            prepTime: nil, performTime: nil, nutrition: nil, settings: nil,
            dateAdded: nil, dateUpdated: nil, createdAt: nil, updatedAt: nil,
            orgURL: nil, extras: nil)
        XCTAssertThrowsError(try store.saveRecipe(invalid))
        XCTAssertEqual(store.recipeCount(), 0)
    }
}
