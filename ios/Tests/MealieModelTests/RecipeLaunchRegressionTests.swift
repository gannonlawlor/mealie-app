import Foundation
import SwiftData
import XCTest
@testable import MealieModel

private final class LaunchURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @MainActor @Sendable (URLRequest) async throws -> (Int, String)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    private var responseTask: Task<Void, Never>?
    static func install(_ handler: Handler?) { lock.withLock { self.handler = handler } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.lock.withLock { Self.handler! }
        responseTask = Task {
            do {
                let (code, body) = try await handler(request)
                guard !Task.isCancelled else { return }
                client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code,
                    httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { responseTask?.cancel() }
}

@MainActor
final class RecipeLaunchRegressionTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var directory: URL!
    private var session: URLSession!
    private var api: MealieAPI!
    private var sync: RecipeSyncService!
    private var store: LocalRecipeStore!

    override func setUp() async throws {
        suite = UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LaunchURLProtocol.self]
        session = URLSession(configuration: config)
        api = MealieAPI(session: session)
        api.configure(baseURL: "https://launch-test.invalid", token: "disposable-test-token")
        sync = RecipeSyncService(api: api, defaults: defaults, directory: directory)
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        store = LocalRecipeStore(store: try SwiftDataRecipeStore(configuration:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)))
    }

    override func tearDown() async throws {
        session.invalidateAndCancel()
        LaunchURLProtocol.install(nil)
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    private func recipe(_ id: String, slug: String = "soup", description: String = "") throws -> Recipe {
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "slug": slug, "name": "Soup", "description": description])
        return try JSONDecoder().decode(Recipe.self, from: data)
    }

    func testSameSlugRecipesNavigateEditFavoriteAndDeleteIndependently() async throws {
        try store.saveRecipe(recipe("first", description: "first record"))
        try store.saveRecipe(recipe("second", description: "second record"))
        let vm = RecipeViewModel(localStore: store)
        vm.isLocalMode = true
        await vm.loadRecipes(reset: true)
        let first = try XCTUnwrap(vm.recipes.first { $0.id == "first" }?.slug)
        let second = try XCTUnwrap(vm.recipes.first { $0.id == "second" }?.slug)
        XCTAssertNotEqual(first, second)
        await vm.loadRecipeDetail(slug: second)
        XCTAssertEqual(vm.selectedRecipe?.description, "second record")
        let saved = await vm.updateRecipe(slug: "soup", data: try recipe("second", description: "edited second"))
        XCTAssertTrue(saved)
        XCTAssertEqual(vm.selectedRecipe?.id, "second")
        await vm.toggleFavorite(slug: second, userId: "")
        vm.loadFavorites(user: nil)
        XCTAssertFalse(vm.isFavorite(slug: first))
        XCTAssertTrue(vm.isFavorite(slug: second))
        let deleted = await vm.deleteRecipe(slug: second)
        XCTAssertTrue(deleted)
        XCTAssertEqual(store.loadAllRecipes().compactMap(\.id), ["first"])
    }

    func testRefreshFetchesServerChangesAfterInitialSync() async throws {
        LaunchURLProtocol.install { request in
            if request.url!.path == "/api/recipes" {
                return (200, "{\"items\":[{\"id\":\"old\",\"slug\":\"old\",\"name\":\"Old\"}],\"page\":1,\"per_page\":50,\"total\":1,\"total_pages\":1}")
            }
            return (200, "{\"id\":\"old\",\"slug\":\"old\",\"name\":\"Old\"}")
        }
        await sync.syncAll()
        let vm = RecipeViewModel(localStore: store, api: api, syncService: sync)
        await vm.loadRecipes(reset: true)
        XCTAssertEqual(vm.recipes.compactMap(\.id), ["old"])
        LaunchURLProtocol.install { request in
            if request.url!.path == "/api/recipes" {
                return (200, "{\"items\":[{\"id\":\"new\",\"slug\":\"new\",\"name\":\"New\"}],\"page\":1,\"per_page\":50,\"total\":1,\"total_pages\":1}")
            }
            return (200, "{\"id\":\"new\",\"slug\":\"new\",\"name\":\"New\",\"description\":\"fresh\"}")
        }
        await vm.refreshRecipes()
        XCTAssertEqual(vm.recipes.compactMap(\.id), ["new"])
        await vm.loadRecipeDetail(slug: "new")
        XCTAssertEqual(vm.selectedRecipe?.description, "fresh")
        XCTAssertNil(sync.loadRecipeBySlug(slug: "old"))
    }

    func testLegacyFavoritesMigrateAndStayIndependent() async throws {
        try store.saveRecipe(recipe("first"))
        try store.saveRecipe(recipe("second"))
        try store.saveFavorites(["soup"])
        let vm = RecipeViewModel(localStore: store)
        vm.isLocalMode = true
        vm.loadFavorites(user: nil)
        XCTAssertEqual(vm.favoriteRecipes, ["local:first", "local:second"])
        await vm.toggleFavorite(slug: "local:second", userId: "")
        vm.loadFavorites(user: nil)
        XCTAssertEqual(vm.favoriteRecipes, ["local:first"])
        XCTAssertEqual(store.loadFavorites(), ["local:first"])
    }

    func testRefreshUpdatesOpenRecipeAndRetainsCacheOnFailure() async throws {
        var revision = "1"
        LaunchURLProtocol.install { request in
            if request.url!.path == "/api/recipes" {
                return (200, "{\"items\":[{\"id\":\"soup\",\"slug\":\"soup\",\"name\":\"Soup \(revision)\",\"dateUpdated\":\"\(revision)\"}],\"page\":1,\"per_page\":50,\"total\":1,\"total_pages\":1}")
            }
            return (200, "{\"id\":\"soup\",\"slug\":\"soup\",\"name\":\"Soup\",\"description\":\"revision \(revision)\",\"dateUpdated\":\"\(revision)\"}")
        }
        let vm = RecipeViewModel(localStore: store, api: api, syncService: sync)
        await vm.refreshRecipes()
        await vm.loadRecipeDetail(slug: "soup")
        revision = "2"
        await vm.refreshRecipes()
        XCTAssertEqual(vm.recipes.first?.name, "Soup 2")
        XCTAssertEqual(vm.selectedRecipe?.description, "revision 2")
        LaunchURLProtocol.install { _ in (503, "{}") }
        await vm.refreshRecipes()
        XCTAssertEqual(vm.recipes.first?.name, "Soup 2")
        XCTAssertEqual(vm.selectedRecipe?.description, "revision 2")
        XCTAssertTrue(vm.errorMessage.contains("Failed to refresh"))
        XCTAssertFalse(sync.isSyncing)
    }

    private func note(_ request: URLRequest) throws -> String {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap((JSONSerialization.jsonObject(with: data) as? [String: Any])?["note"] as? String)
    }

    private func ingredient(_ note: String) -> RecipeIngredient {
        RecipeIngredient(quantity: nil, unit: nil, food: nil, note: note, isFood: nil,
            disableAmount: nil, display: nil, title: nil, originalText: nil, referenceId: nil)
    }

    func testShoppingRetryPostsOnlyUnacknowledgedItems() async throws {
        let queue = LocalGroceryStore(defaults: defaults)
        let vm = ShoppingViewModel(api: api, groceryStore: queue)
        vm.addIngredientLocally(listId: suite, ingredient: ingredient("good"))
        vm.addIngredientLocally(listId: suite, ingredient: ingredient("bad"))
        var posted: [String] = []
        var fail = true
        LaunchURLProtocol.install { request in
            if request.httpMethod == "POST" {
                let note = try self.note(request)
                if note == "bad" && fail { return (500, "{}") }
                posted.append(note)
            }
            return (200, "{\"id\":\"test-list\"}")
        }
        await vm.syncPendingItems(forListId: suite)
        XCTAssertEqual(LocalGroceryStore(defaults: defaults).pendingItems(forListId: suite).map(\.note), ["bad"])
        fail = false
        await vm.syncPendingItems(forListId: suite)
        XCTAssertEqual(posted, ["good", "bad"])
        XCTAssertTrue(queue.pendingItems(forListId: suite).isEmpty)
        XCTAssertFalse(vm.isSyncing)
    }

    func testShoppingDrainPreservesNewItemsAndRejectsReentry() async throws {
        let queue = LocalGroceryStore(defaults: defaults)
        let vm = ShoppingViewModel(api: api, groceryStore: queue)
        vm.addIngredientLocally(listId: suite, ingredient: ingredient("first"))
        var calls = 0
        LaunchURLProtocol.install { request in
            if request.httpMethod == "POST" {
                calls += 1
                if calls == 1 {
                    vm.addIngredientLocally(listId: self.suite, ingredient: self.ingredient("later"))
                    await vm.syncPendingItems(forListId: self.suite)
                }
            }
            return (200, "{\"id\":\"test-list\"}")
        }
        await vm.syncPendingItems(forListId: suite)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(queue.pendingItems(forListId: suite).map(\.note), ["later"])
        XCTAssertFalse(vm.isSyncing)
    }
}
