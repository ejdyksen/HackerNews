// Lightweight settings sheet. For now this only exposes account actions, but
// it gives the app a modal settings entry point instead of a list row.
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showExtraLists") private var showExtraLists = false
    @AppStorage("hideWebsitePreviews") private var hideWebsitePreviews = false
    @StateObject private var authController = AuthController.shared
    @State private var showingLoginSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Home") {
                    Toggle("Show Extra Lists", isOn: $showExtraLists)
                    Toggle("Hide Website Previews", isOn: $hideWebsitePreviews)
                }

                Section("Account") {
                    if authController.isLoggedIn {
                        LabeledContent("Signed In") {
                            Text(authController.username ?? "User")
                                .foregroundStyle(.secondary)
                        }

                        Button("Logout", role: .destructive) {
                            Task {
                                await authController.logout()
                            }
                        }
                    } else {
                        Button("Login") {
                            showingLoginSheet = true
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingLoginSheet) {
            LoginView()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
