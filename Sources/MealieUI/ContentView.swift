import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

public struct ContentView: View {
    @State var authVM = AuthViewModel()
    @State var recipeVM = RecipeViewModel()
    @State var mealPlanVM = MealPlanViewModel()
    @State var shoppingVM = ShoppingViewModel()
    @State var selectedTab: AppTab = .recipes
    @State var appTheme: AppTheme = AppSettings.shared.theme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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
            if authVM.isAuthenticated {
                if horizontalSizeClass == .regular {
                    iPadLayout
                        .task {
                            recipeVM.isLocalMode = authVM.isLocalMode
                            if authVM.isLocalMode {
                                recipeVM.loadFavorites(user: nil)
                            } else {
                                await authVM.loadCurrentUser()
                                recipeVM.loadFavorites(user: authVM.currentUser)
                                recipeVM.loadOfflineIds()
                            }
                        }
                } else {
                    mainTabView
                        .task {
                            recipeVM.isLocalMode = authVM.isLocalMode
                            if authVM.isLocalMode {
                                recipeVM.loadFavorites(user: nil)
                            } else {
                                await authVM.loadCurrentUser()
                                recipeVM.loadFavorites(user: authVM.currentUser)
                                recipeVM.loadOfflineIds()
                            }
                        }
                }
            } else {
                LoginView(authVM: authVM)
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .onOpenURL { url in
            guard authVM.isAuthenticated else { return }
            let recipeURL: String
            if url.scheme == "mealie" {
                // iOS: mealie://import?url=<encoded_url>
                #if os(Android)
                recipeURL = ""
                #else
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
                    return
                }
                recipeURL = queryURL
                #endif
            } else {
                // Android: raw recipe URL via ACTION_VIEW
                recipeURL = url.absoluteString
            }
            guard !recipeURL.isEmpty else { return }
            recipeVM.importURL = recipeURL
            Task {
                await recipeVM.importFromURL()
            }
        }
    }

    var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RecipeListView(recipeVM: recipeVM)
            }
            .tag(AppTab.recipes)
            .tabItem {
                Label("Recipes", systemImage: "book")
            }

            if !authVM.isLocalMode {
                NavigationStack {
                    MealPlanView(mealPlanVM: mealPlanVM, recipeVM: recipeVM)
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
                SettingsView(authVM: authVM, onThemeChange: { appTheme = $0 })
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }

    var iPadLayout: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab, authVM: authVM, isLocalMode: authVM.isLocalMode)

            Divider()

            // Content area
            Group {
                switch selectedTab {
                case .recipes:
                    RecipeSplitView(recipeVM: recipeVM)
                case .mealPlan:
                    NavigationStack {
                        MealPlanView(mealPlanVM: mealPlanVM, recipeVM: recipeVM)
                    }

                case .shopping:
                    ShoppingSplitView(shoppingVM: shoppingVM)
                case .settings:
                    NavigationStack {
                        SettingsView(authVM: authVM, onThemeChange: { appTheme = $0 })
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
