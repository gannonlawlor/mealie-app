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
    var onThemeChange: ((AppTheme) -> Void)? = nil
    @State var showLogoutAlert = false
    @State var selectedTheme: AppTheme = AppSettings.shared.theme

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
            } else {
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
                if authVM.isLocalMode {
                    Button(action: { showLogoutAlert = true }) {
                        Label("Connect to Server", systemImage: "server.rack")
                    }
                } else {
                    Button(action: {
                        Task { await authVM.loadCurrentUser() }
                    }) {
                        Label("Refresh Profile", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: { showLogoutAlert = true }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert(authVM.isLocalMode ? "Connect to Server" : "Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button(authVM.isLocalMode ? "Continue" : "Sign Out", role: authVM.isLocalMode ? nil : .destructive) {
                authVM.logout()
            }
        } message: {
            Text(authVM.isLocalMode
                 ? "You'll be taken to the login screen. Your local recipes will be preserved."
                 : "Are you sure you want to sign out?")
        }
        .task {
            if !authVM.isLocalMode, authVM.serverInfo == nil {
                do {
                    authVM.serverInfo = try await MealieAPI.shared.getAppInfo()
                } catch {
                    // Ignore
                }
            }
        }
    }
}
