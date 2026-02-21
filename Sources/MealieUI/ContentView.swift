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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    public init() {
    }

    public var body: some View {
        if authVM.isAuthenticated {
            if horizontalSizeClass == .regular {
                iPadLayout
                    .task {
                        await authVM.loadCurrentUser()
                    }
            } else {
                mainTabView
                    .task {
                        await authVM.loadCurrentUser()
                    }
            }
        } else {
            LoginView(authVM: authVM)
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

            NavigationStack {
                SettingsView(authVM: authVM)
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
                    RecipeSplitView(recipeVM: recipeVM)
                case .mealPlan:
                    NavigationStack {
                        MealPlanView(mealPlanVM: mealPlanVM, recipeVM: recipeVM)
                    }
                case .shopping:
                    ShoppingSplitView(shoppingVM: shoppingVM)
                case .settings:
                    NavigationStack {
                        SettingsView(authVM: authVM)
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
