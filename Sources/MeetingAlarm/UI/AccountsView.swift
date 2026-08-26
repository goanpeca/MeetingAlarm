import SwiftUI

/// Manage direct-Google accounts: enter the OAuth desktop-client credentials, then add
/// or remove accounts. Each account's meetings are aggregated into the day list.
struct AccountsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var accounts: GoogleAccountStore

    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google OAuth").font(.headline)
            Text("Paste a Google Cloud \"Desktop app\" client. See the README for setup.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Client ID", text: $clientId)
            SecureField("Client secret", text: $clientSecret)
            Button("Save credentials") {
                coordinator.setGoogleCredentials(clientId: clientId, clientSecret: clientSecret)
            }
            .disabled(clientId.isEmpty || clientSecret.isEmpty)

            Divider()

            HStack {
                Text("Accounts").font(.headline)
                Spacer()
                Button {
                    isAdding = true
                    Task {
                        await coordinator.addGoogleAccount()
                        isAdding = false
                    }
                } label: {
                    if isAdding {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Add account")
                    }
                }
                .disabled(!coordinator.isGoogleConfigured || isAdding)
            }

            if accounts.accounts.isEmpty {
                Text("No accounts connected.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(accounts.accounts) { account in
                    HStack {
                        Text(account.email)
                        Spacer()
                        Button("Remove") { coordinator.removeGoogleAccount(id: account.id) }
                            .buttonStyle(.borderless)
                    }
                }
            }

            if let error = coordinator.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .onAppear { clientId = coordinator.googleClientId }
    }
}
