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
    var isLocalMode: Bool = false
    @State var showLogoutAlert = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User header
            if isLocalMode {
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
            } else if let user = authVM.currentUser {
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

            Divider()

            // Tab buttons
            VStack(spacing: 4) {
                sidebarButton(tab: .recipes, icon: "book", label: "Recipes")
                if !isLocalMode {
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
            if isLocalMode {
                Button(action: { showLogoutAlert = true }) {
                    Label("Connect to Server", systemImage: "server.rack")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .alert("Connect to Server", isPresented: $showLogoutAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Continue") {
                        authVM.logout()
                    }
                } message: {
                    Text("You'll be taken to the login screen. Your local recipes will be preserved.")
                }
            } else {
                Button(action: { showLogoutAlert = true }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .alert("Sign Out", isPresented: $showLogoutAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Sign Out", role: .destructive) {
                        authVM.logout()
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }
            }
        }
        .frame(width: 240)
        .background(AdaptiveColors.color(.sidebar, isDark: colorScheme == .dark))
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
