import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct SettingsView: View {
    @Bindable var authVM: AuthViewModel
    @Bindable var shoppingVM: ShoppingViewModel
    var onThemeChange: ((AppTheme) -> Void)? = nil
    @State var showLogoutAlert = false
    @State var showLoginSheet = false
    @State var selectedTheme: AppTheme = AppSettings.shared.theme
    @State var keepScreenAwake: Bool = AppSettings.shared.keepScreenAwake
    @State var addToReminders: Bool = AppSettings.shared.addToReminders
    @State var localGroceryList: Bool = AppSettings.shared.localGroceryList
    @State var defaultListId: String = AppSettings.shared.defaultShoppingListId ?? ""
    #if !os(Android)
    @State var iCloudSync: Bool = AppSettings.shared.iCloudSync
    @State var iCloudAvailable: Bool = false
    #endif

    var body: some View {
        List {
            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTheme) { _, newValue in
                    AppSettings.shared.theme = newValue
                    onThemeChange?(newValue)
                }
            }

            Section {
                Toggle("Keep Screen Awake", isOn: $keepScreenAwake)
                    .onChange(of: keepScreenAwake) { _, newValue in
                        AppSettings.shared.keepScreenAwake = newValue
                    }
            } footer: {
                Text("Prevents the screen from dimming while viewing a recipe.")
            }

            if authVM.isServerConnected {
                Section {
                    Picker("Default Shopping List", selection: $defaultListId) {
                        Text("Ask Every Time").tag("")
                        ForEach(shoppingVM.shoppingLists) { list in
                            Text(list.name ?? "Untitled").tag(list.id ?? "")
                        }
                    }
                    .onChange(of: defaultListId) { _, newValue in
                        if newValue.isEmpty {
                            AppSettings.shared.defaultShoppingListId = nil
                            AppSettings.shared.defaultShoppingListName = nil
                        } else {
                            AppSettings.shared.defaultShoppingListId = newValue
                            AppSettings.shared.defaultShoppingListName = shoppingVM.shoppingLists.first(where: { $0.id == newValue })?.name
                        }
                    }

                    Toggle("Queue Items Locally", isOn: $localGroceryList)
                        .onChange(of: localGroceryList) { _, newValue in
                            AppSettings.shared.localGroceryList = newValue
                        }
                } header: {
                    Text("Shopping Lists")
                } footer: {
                    Text("Set a default list to skip the picker when adding ingredients. Queue locally to save items offline and upload later.")
                }
            }

            #if !os(Android)
            Section {
                Toggle("Add to iOS Reminders", isOn: $addToReminders)
                    .onChange(of: addToReminders) { _, newValue in
                        AppSettings.shared.addToReminders = newValue
                        if newValue {
                            Task {
                                let granted = await RemindersService.shared.requestAccess()
                                if !granted {
                                    addToReminders = false
                                    AppSettings.shared.addToReminders = false
                                }
                            }
                        }
                    }
            } footer: {
                Text("When adding ingredients to a shopping list, also add them to your Reminders grocery list.")
            }
            #endif

            if authVM.isLocalMode {
                // Local Mode Info
                Section("Mode") {
                    HStack {
                        Text("Mode")
                        Spacer()
                        Text("Local")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Recipes")
                        Spacer()
                        Text("\(LocalRecipeStore.shared.recipeCount())")
                            .foregroundStyle(.secondary)
                    }
                }

                #if !os(Android)
                Section {
                    Toggle("iCloud Sync", isOn: $iCloudSync)
                        .disabled(!iCloudAvailable)
                        .onChange(of: iCloudSync) { _, newValue in
                            AppSettings.shared.iCloudSync = newValue
                            if newValue {
                                ICloudSyncManager.shared.enableICloudSync()
                            } else {
                                ICloudSyncManager.shared.disableICloudSync()
                            }
                        }
                } footer: {
                    if iCloudAvailable {
                        Text("Sync your local recipes across all your iOS devices using iCloud.")
                    } else {
                        Text("iCloud is not available. Sign in to iCloud in Settings to enable sync.")
                    }
                }
                #endif
            }

            if authVM.isServerConnected {
                // User Profile Section
                if let user = authVM.currentUser {
                    Section("Profile") {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName ?? user.username ?? "User")
                                    .font(.headline)
                                Text(user.email ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Server Info
                Section("Server") {
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(AuthService.shared.savedServerURL ?? "Not connected")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let info = authVM.serverInfo {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("v\(info.version)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // App Info
            Section("About") {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Built with")
                    Spacer()
                    Text("Skip + SwiftUI")
                        .foregroundStyle(.secondary)
                }
            }

            // Actions
            Section {
                if authVM.isServerConnected {
                    Button(action: {
                        Task { await authVM.loadCurrentUser() }
                    }) {
                        Label("Refresh Profile", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: { showLogoutAlert = true }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button(action: {
                        if authVM.isLocalMode {
                            showLogoutAlert = true
                        } else {
                            authVM.showServerSetup = true
                            authVM.errorMessage = ""
                            authVM.serverInfo = nil
                            showLoginSheet = true
                        }
                    }) {
                        Label("Connect to Server", systemImage: "server.rack")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert(authVM.isLocalMode ? "Connect to Server" : "Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            if authVM.isLocalMode {
                Button("Continue") {
                    authVM.showServerSetup = true
                    authVM.errorMessage = ""
                    authVM.serverInfo = nil
                    showLoginSheet = true
                }
            } else {
                Button("Sign Out", role: .destructive) {
                    authVM.logout()
                }
            }
        } message: {
            Text(authVM.isLocalMode
                 ? "Your local recipes will be preserved."
                 : "Are you sure you want to sign out?")
        }
        .task {
            if authVM.isServerConnected {
                if authVM.serverInfo == nil {
                    do {
                        authVM.serverInfo = try await MealieAPI.shared.getAppInfo()
                    } catch {
                        // Ignore
                    }
                }
                if shoppingVM.shoppingLists.isEmpty {
                    await shoppingVM.loadShoppingLists()
                }
            }
            #if !os(Android)
            iCloudAvailable = ICloudSyncManager.shared.isICloudAvailable()
            #endif
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView(authVM: authVM, hideLocalMode: authVM.isLocalMode)
        }
        .onChange(of: authVM.isServerConnected) { _, connected in
            if connected { showLoginSheet = false }
        }
        .onChange(of: authVM.isAuthenticated) { _, authenticated in
            if authenticated { showLoginSheet = false }
        }
    }
}
