import SwiftUI

/// Token, server and account fields shared by the onboarding screen and Settings.
struct ConnectionForm: View {
    @Environment(AppState.self) private var state
    var submitTitle: String
    var onConnected: () -> Void = {}

    @State private var token = ""
    @State private var serverURL = ""
    @State private var account = ""
    @State private var isConnecting = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                SecureField(
                    "Token de acceso personal",
                    text: $token,
                    prompt: Text(state.isConfigured ? "Deja vacío para mantener el actual" : "github_pat_… o ghp_…")
                )
                TextField("Servidor de GitHub", text: $serverURL, prompt: Text("https://github.com"))
                TextField("Cuenta u organización", text: $account, prompt: Text("Opcional: mi-org o https://github.com/mi-org"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("El token necesita permiso de escritura sobre los secretos de los repositorios: en un token *fine-grained*, «Secrets: Read and write» (y «Dependabot secrets», «Codespaces secrets» o «Environments» si los usas); en un token clásico, el scope `repo`.")
                    Text("La cuenta es opcional y solo filtra la lista de repositorios. Para GitHub Enterprise Server indica la URL de tu servidor.")
                    HStack(spacing: 16) {
                        Link("Crear token fine-grained", destination: tokenURL("settings/personal-access-tokens/new"))
                        Link("Crear token clásico", destination: tokenURL("settings/tokens/new?scopes=repo&description=Repository%20Manager"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(submitTitle, action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isConnecting || (!state.isConfigured && token.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .formStyle(.grouped)
        .onAppear {
            serverURL = state.settings.serverURL
            account = state.settings.account
        }
    }

    private func tokenURL(_ path: String) -> URL {
        var server = serverURL.trimmingCharacters(in: .whitespaces)
        if server.isEmpty { server = "https://github.com" }
        if !server.contains("://") { server = "https://" + server }
        if server.hasSuffix("/") { server.removeLast() }
        return URL(string: "\(server)/\(path)") ?? URL(string: "https://github.com/\(path)")!
    }

    private func submit() {
        let tokenToUse = token.isEmpty ? state.token : token
        isConnecting = true
        error = nil
        Task {
            defer { isConnecting = false }
            do {
                try await state.connect(token: tokenToUse, serverURL: serverURL, account: account)
                token = ""
                serverURL = state.settings.serverURL
                account = state.settings.account
                onConnected()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Repository Manager")
                .font(.largeTitle.bold())
            Text("Define conjuntos de secretos y súbelos a cualquier repositorio de GitHub con un clic.\nPara empezar, conecta tu cuenta con un token de acceso personal (PAT).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            ConnectionForm(submitTitle: "Conectar")
                .frame(maxWidth: 560, maxHeight: 400)
            Text("El token se guarda en el Llavero de macOS y solo se envía a GitHub.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var saved = false
    @State private var confirmDisconnect = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isConfigured {
                HStack {
                    Label("Conectado como \(state.settings.login)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    if saved {
                        Text("Guardado")
                            .foregroundStyle(.secondary)
                    }
                    Button("Desconectar…", role: .destructive) { confirmDisconnect = true }
                }
                .padding([.horizontal, .top], 20)
            }
            ConnectionForm(submitTitle: state.isConfigured ? "Guardar" : "Conectar") {
                saved = true
            }
        }
        .frame(width: 560, height: 420)
        .confirmationDialog("¿Desconectar la cuenta?", isPresented: $confirmDisconnect) {
            Button("Desconectar", role: .destructive) { state.disconnect() }
        } message: {
            Text("Se borrará el token del Llavero. Tus conjuntos de secretos se conservan.")
        }
    }
}
