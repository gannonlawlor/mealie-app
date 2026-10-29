import SnapshotTesting
import SwiftUI
import XCTest
@testable import MealieModel
@testable import MealieUI

/// Screenshot tests for the key screens, rendered with deterministic fixture
/// state (see `Fixtures.swift`). Goldens live in `__Snapshots__/`.
///
/// Determinism notes:
/// - ViewModels are constructed and populated directly; every screen that has a
///   `.task` loader is snapshotted in a state where the load either exits early
///   (non-empty data) or no-ops on failure (unconfigured `MealieAPI` throws and
///   the catch block leaves existing state untouched).
/// - `RecipeDetailView` is the exception: its `.task` unconditionally replaces
///   `selectedRecipe`, so we snapshot its `recipeContent(_:)` subview instead.
/// - `MealieAPI.shared` is never configured, so image URLs are relative/dead and
///   `AsyncImage` stably renders its placeholder.
@MainActor
final class MealieUISnapshotTests: XCTestCase {

    // MARK: - Helpers

    private var phone: ViewImageConfig { .iPhone13(.portrait) }
    private var pad: ViewImageConfig { .iPadPro11(.landscape) }

    private func assertDeviceSnapshot(
        of view: some View,
        config: ViewImageConfig,
        dark: Bool = false,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        UIView.setAnimationsEnabled(false)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.98,
                layout: .device(config: config),
                traits: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            ),
            file: file,
            testName: testName,
            line: line
        )
    }

    private func makeAuthVM() -> AuthViewModel {
        let authVM = AuthViewModel()
        authVM.serverURL = ""
        authVM.email = ""
        authVM.password = ""
        authVM.isLoading = false
        authVM.errorMessage = ""
        authVM.isAuthenticated = false
        authVM.isServerConnected = false
        authVM.currentUser = nil
        authVM.serverInfo = nil
        authVM.showServerSetup = true
        authVM.savedServers = []
        return authVM
    }

    // MARK: - Login

    func testLoginViewServerSetup() {
        let authVM = makeAuthVM()
        authVM.savedServers = [Fixtures.savedServer]
        assertDeviceSnapshot(of: LoginView(authVM: authVM), config: phone)
    }

    func testLoginViewLoginForm() {
        let authVM = makeAuthVM()
        authVM.showServerSetup = false
        authVM.serverURL = "https://mealie.example.com"
        authVM.email = "demo@example.com"
        authVM.password = "swordfish!"
        assertDeviceSnapshot(of: LoginView(authVM: authVM), config: phone)
    }

    // MARK: - Recipes

    func testRecipeListView() {
        let recipeVM = RecipeViewModel()
        recipeVM.isLocalMode = true // rows render the static photo placeholder, no AsyncImage
        recipeVM.recipes = Fixtures.recipeSummaries
        recipeVM.currentPage = 1
        recipeVM.totalPages = 1

        let view = NavigationStack {
            RecipeListView(
                recipeVM: recipeVM,
                shoppingVM: ShoppingViewModel(),
                mealPlanVM: MealPlanViewModel()
            )
        }
        assertDeviceSnapshot(of: view, config: phone)
    }

    private func recipeDetailContent() -> some View {
        let recipeVM = RecipeViewModel()
        recipeVM.selectedRecipe = Fixtures.recipe
        let detail = RecipeDetailView(
            recipeVM: recipeVM,
            shoppingVM: ShoppingViewModel(),
            mealPlanVM: MealPlanViewModel(),
            slug: Fixtures.recipe.slug ?? ""
        )
        return detail.recipeContent(Fixtures.recipe)
            .background(Color(uiColor: .systemBackground))
    }

    func testRecipeDetailContent() {
        assertDeviceSnapshot(of: recipeDetailContent(), config: phone)
    }

    func testRecipeDetailContentDark() {
        assertDeviceSnapshot(of: recipeDetailContent(), config: phone, dark: true)
    }

    // MARK: - Meal plan

    func testMealPlanViewWeek() {
        let mealPlanVM = MealPlanViewModel()
        mealPlanVM.currentWeekStart = Fixtures.weekStart
        mealPlanVM.weekEntries = Fixtures.weekEntries

        let view = NavigationStack {
            MealPlanView(
                mealPlanVM: mealPlanVM,
                recipeVM: RecipeViewModel(),
                shoppingVM: ShoppingViewModel()
            )
        }
        assertDeviceSnapshot(of: view, config: phone)
    }

    // MARK: - Shopping

    func testShoppingListDetailView() {
        let listId = Fixtures.shoppingListId
        LocalGroceryStore.shared.clearPendingItems(forListId: listId)
        LocalGroceryStore.shared.addPendingItem(
            PendingGroceryItem(shoppingListId: listId, note: "2 tbsp olive oil"),
            forListId: listId
        )
        addTeardownBlock {
            LocalGroceryStore.shared.clearPendingItems(forListId: listId)
        }

        let shoppingVM = ShoppingViewModel()
        shoppingVM.selectedList = Fixtures.shoppingList
        shoppingVM.refreshPendingCounts()

        let view = NavigationStack {
            ShoppingListDetailView(shoppingVM: shoppingVM, listId: listId)
        }
        assertDeviceSnapshot(of: view, config: phone)
    }

    // MARK: - Settings

    func testSettingsViewLocalMode() {
        let previousMode = AuthService.shared.savedAppMode
        AuthService.shared.savedAppMode = .local
        addTeardownBlock {
            AuthService.shared.savedAppMode = previousMode
        }

        // Pin the UserDefaults-backed settings the screen reads.
        AppSettings.shared.theme = .system
        AppSettings.shared.keepScreenAwake = false
        AppSettings.shared.addToReminders = false
        AppSettings.shared.iCloudSync = false

        let authVM = makeAuthVM()
        authVM.isAuthenticated = true
        authVM.showServerSetup = false

        let view = NavigationStack {
            SettingsView(authVM: authVM, shoppingVM: ShoppingViewModel(), appVersion: "1.1.19")
        }
        assertDeviceSnapshot(of: view, config: phone)
    }

    // MARK: - iPad split layout

    func testRecipeSplitViewIPad() {
        let recipeVM = RecipeViewModel()
        recipeVM.isLocalMode = true
        recipeVM.recipes = Fixtures.recipeSummaries
        recipeVM.currentPage = 1
        recipeVM.totalPages = 1

        let view = RecipeSplitView(
            recipeVM: recipeVM,
            shoppingVM: ShoppingViewModel(),
            mealPlanVM: MealPlanViewModel()
        )
        assertDeviceSnapshot(of: view, config: pad)
    }

    func testSidebarViewIPad() {
        let authVM = makeAuthVM()
        authVM.isAuthenticated = true
        authVM.isServerConnected = true
        authVM.showServerSetup = false
        authVM.currentUser = Fixtures.user

        let view = HStack(spacing: 0) {
            SidebarView(selectedTab: .constant(.recipes), authVM: authVM)
            Divider()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        assertDeviceSnapshot(of: view, config: pad)
    }
}
