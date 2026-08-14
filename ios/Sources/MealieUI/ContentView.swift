import Foundation
import SwiftUI
import MealieModel

public struct ContentView: View {
    @State var authVM = AuthViewModel()
    @State var recipeVM = RecipeViewModel()
    @State var mealPlanVM = MealPlanViewModel()
    @State var shoppingVM = ShoppingViewModel()
    @State var selectedTab: AppTab = .recipes
    @State var appTheme: AppTheme = AppSettings.shared.theme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase

    public init() {
    }

    var resolvedColorScheme: ColorScheme? {
        switch appTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                mainTabView
            }
        }
        .task {
            let vm = authVM
            MealieAPI.shared.onUnauthorized = {
                vm.softLogout()
            }
            recipeVM.isLocalMode = !authVM.isServerConnected
            if authVM.isServerConnected {
                await authVM.loadCurrentUser()
                recipeVM.loadFavorites(user: authVM.currentUser)
                recipeVM.loadOfflineIds()
                Task.detached { await RecipeSyncService.shared.syncAll() }
            } else {
                recipeVM.loadFavorites(user: nil)
            }
            // scenePhase may already be .active on a cold launch, so the
            // onChange below never fires for links shared while the app was
            // not running.
            await processShareImports()
        }
        .onChange(of: authVM.isServerConnected) { _, connected in
            recipeVM.isLocalMode = !connected
            if connected {
                Task {
                    await authVM.loadCurrentUser()
                    recipeVM.loadFavorites(user: authVM.currentUser)
                    recipeVM.loadOfflineIds()
                    await recipeVM.loadRecipes(reset: true)
                    Task.detached { await RecipeSyncService.shared.syncAll() }
                }
            } else {
                if selectedTab == .mealPlan || selectedTab == .shopping {
                    selectedTab = .recipes
                }
                recipeVM.loadFavorites(user: nil)
                Task { await recipeVM.loadRecipes(reset: true) }
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .onOpenURL { url in
            let recipeURL: String
            if url.scheme == "mealie" {
                // iOS: mealie://import?url=<encoded_url>
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
                    return
                }
                recipeURL = queryURL
            } else {
                recipeURL = url.absoluteString
            }
            guard !recipeURL.isEmpty else { return }
            recipeVM.importURL = recipeURL
            Task {
                await recipeVM.importFromURL()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await processShareImports() }
            }
        }
    }

    /// Settles anything the Share Extension left behind: recipes it already
    /// created on the server (which still need pulling into the sync store so
    /// the list shows them), and links it could not import itself.
    @MainActor
    private func processShareImports() async {
        guard let queue = SharedImportQueue.shared else {
            print("[ShareImport] App Group unavailable — cannot read shared imports")
            if authVM.isServerConnected {
                await recipeVM.loadRecipes(reset: true)
            }
            return
        }

        let completed = queue.completedSlugs()
        let pending = queue.pendingURLs()
        print("[ShareImport] completed: \(completed.count), pending: \(pending.count), serverConnected: \(authVM.isServerConnected)")

        // Imports the extension finished — fetch them so they appear right away.
        if !completed.isEmpty && authVM.isServerConnected {
            queue.clearCompleted()
            selectedTab = .recipes
            for slug in completed {
                await recipeVM.ingestImportedRecipe(slug: slug)
            }
        }

        guard !pending.isEmpty else {
            if completed.isEmpty && authVM.isServerConnected {
                // Refresh recipe list when returning to foreground
                await recipeVM.loadRecipes(reset: true)
            }
            return
        }

        // Signed out of a server: leave the links queued rather than failing them.
        guard authVM.isServerConnected || recipeVM.isLocalMode else {
            print("[ShareImport] not connected — leaving \(pending.count) link(s) queued")
            return
        }

        selectedTab = .recipes
        var failed: [String] = []
        for urlString in pending {
            recipeVM.importURL = urlString
            if await recipeVM.importFromURL() {
                queue.remove(urlString)
                print("[ShareImport] imported queued link: \(urlString)")
            } else {
                failed.append(urlString)
                print("[ShareImport] import failed, keeping for retry: \(urlString)")
            }
            // A duplicate needs the user's answer before importing anything else.
            if recipeVM.showDuplicateAlert { break }
        }

        if !failed.isEmpty {
            recipeVM.errorMessage = failed.count == 1
                ? "A shared link couldn't be imported. It will be retried next time you open Mealie."
                : "\(failed.count) shared links couldn't be imported. They will be retried next time you open Mealie."
            recipeVM.errorDetail = failed.joined(separator: "\n")
        }
    }

    var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RecipeListView(recipeVM: recipeVM, shoppingVM: shoppingVM, mealPlanVM: mealPlanVM)
            }
            .tag(AppTab.recipes)
            .tabItem {
                Label("Recipes", systemImage: "book")
            }

            if authVM.isServerConnected {
                NavigationStack {
                    MealPlanView(mealPlanVM: mealPlanVM, recipeVM: recipeVM, shoppingVM: shoppingVM)
                }
                .tag(AppTab.mealPlan)
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }

                NavigationStack {
                    ShoppingListsView(shoppingVM: shoppingVM)
                }
                .tag(AppTab.shopping)
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }
            }

            NavigationStack {
                SettingsView(authVM: authVM, shoppingVM: shoppingVM, onThemeChange: { appTheme = $0 })
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    var iPadLayout: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab, authVM: authVM)

            Divider()

            // Content area
            Group {
                switch selectedTab {
                case .recipes:
                    RecipeSplitView(recipeVM: recipeVM, shoppingVM: shoppingVM, mealPlanVM: mealPlanVM)
                case .mealPlan:
                    NavigationStack {
                        MealPlanView(mealPlanVM: mealPlanVM, recipeVM: recipeVM, shoppingVM: shoppingVM)
                    }

                case .shopping:
                    ShoppingSplitView(shoppingVM: shoppingVM)
                case .settings:
                    NavigationStack {
                        SettingsView(authVM: authVM, shoppingVM: shoppingVM, onThemeChange: { appTheme = $0 })
                    }

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum AppTab: Hashable {
    case recipes
    case mealPlan
    case shopping
    case settings
}
