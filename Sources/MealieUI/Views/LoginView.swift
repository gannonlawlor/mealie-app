import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct LoginView: View {
    @Bindable var authVM: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // App Logo Area
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                        Text("Mealie")
                            .font(.largeTitle)
                            .bold()
                        Text("Your Recipe Manager")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer().frame(height: 20)

                    if authVM.showServerSetup {
                        serverSetupForm
                    } else {
                        loginForm
                    }

                    if !authVM.errorMessage.isEmpty {
                        Text(authVM.errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("")
        }
    }

    var serverSetupForm: some View {
        VStack(spacing: 16) {
            Text("Connect to Server")
                .font(.headline)

            TextField("Server URL (e.g. mealie.example.com)", text: $authVM.serverURL)
                .autocorrectionDisabled()
                .padding()
                .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                .cornerRadius(10)

            Button(action: {
                Task { await authVM.validateServer() }
            }) {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .foregroundStyle(.white)
            .background(authVM.serverURL.isEmpty ? Color.gray : Color.accentColor)
            .cornerRadius(10)
            .disabled(authVM.serverURL.isEmpty || authVM.isLoading)

            if let info = authVM.serverInfo {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected - v\(info.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var loginForm: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Sign In")
                    .font(.headline)
                Spacer()
                Button("Change Server") {
                    authVM.showServerSetup = true
                    authVM.errorMessage = ""
                }
                .font(.caption)
            }

            TextField("Email", text: $authVM.email)
                .autocorrectionDisabled()
                .padding()
                .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                .cornerRadius(10)

            SecureField("Password", text: $authVM.password)
                .padding()
                .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                .cornerRadius(10)

            Button(action: {
                Task { await authVM.login() }
            }) {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .foregroundStyle(.white)
            .background((authVM.email.isEmpty || authVM.password.isEmpty) ? Color.gray : Color.accentColor)
            .cornerRadius(10)
            .disabled(authVM.email.isEmpty || authVM.password.isEmpty || authVM.isLoading)
        }
    }
}
