import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct SidebarView: View {
    @Binding var selectedTab: AppTab
    @Bindable var authVM: AuthViewModel
    @State var showLogoutAlert = false
    @State var showLoginSheet = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User header
            if authVM.isServerConnected {
                if let user = authVM.currentUser {
                    HStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName ?? user.username ?? "User")
                                .font(.subheadline)
                                .bold()
                                .lineLimit(1)
                            Text(user.email ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else if authVM.isLocalMode {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local Mode")
                            .font(.subheadline)
                            .bold()
                            .lineLimit(1)
                        Text("Recipes saved on device")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mealie")
                            .font(.subheadline)
                            .bold()
                            .lineLimit(1)
                        Text("Connect to get started")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Tab buttons
            VStack(spacing: 4) {
                sidebarButton(tab: .recipes, icon: "book", label: "Recipes")
                if authVM.isServerConnected {
                    sidebarButton(tab: .mealPlan, icon: "calendar", label: "Meal Plan")
                    sidebarButton(tab: .shopping, icon: "cart", label: "Shopping")
                }
                sidebarButton(tab: .settings, icon: "gear", label: "Settings")
            }
            .padding(.top, 12)
            .padding(.horizontal, 8)

            Spacer()

            // Sign out / Connect
            Divider()
            if authVM.isServerConnected {
                Button(action: { showLogoutAlert = true }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
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
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .frame(width: 240)
        .background(AdaptiveColors.color(.sidebar, isDark: colorScheme == .dark))
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

    func sidebarButton(tab: AppTab, icon: String, label: String) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(label)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
            .cornerRadius(8)
        }
    }
}
