import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.isConfigured {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .onChange(of: state.secretSets) {
            state.scheduleSave()
        }
        .alert("No se pudo acceder al Llavero", isPresented: storageErrorPresented) {
            Button("Aceptar") {}
        } message: {
            Text(state.storageError ?? "")
        }
    }

    private var storageErrorPresented: Binding<Bool> {
        Binding(
            get: { state.storageError != nil },
            set: { if !$0 { state.storageError = nil } }
        )
    }
}

struct MainView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let id = state.selectedSetID, state.secretSets.contains(where: { $0.id == id }) {
                SecretSetDetailView(set: binding(for: id))
                    .id(id)
            } else {
                ContentUnavailableView {
                    Label("Ningún conjunto seleccionado", systemImage: "key")
                } description: {
                    Text("Un conjunto agrupa varios secretos y el repositorio al que se envían.")
                } actions: {
                    Button("Nuevo conjunto de secretos") { state.addSet() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            if state.repositories.isEmpty {
                await state.loadRepositories()
            }
        }
        .sheet(isPresented: $state.showUploadSheet) {
            UploadSheet()
        }
    }

    /// Binding looked up by id, so removing sets never leaves a dangling index.
    private func binding(for id: SecretSet.ID) -> Binding<SecretSet> {
        Binding(
            get: { state.secretSets.first(where: { $0.id == id }) ?? SecretSet(id: id, name: "") },
            set: { newValue in
                if let index = state.secretSets.firstIndex(where: { $0.id == id }) {
                    state.secretSets[index] = newValue
                }
            }
        )
    }
}

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @State private var pendingDeletion: SecretSet?

    var body: some View {
        @Bindable var state = state
        List(selection: $state.selectedSetID) {
            Section("Conjuntos de secretos") {
                ForEach(state.secretSets) { set in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.name.isEmpty ? "Sin nombre" : set.name)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(set.repository ?? "Sin repositorio")
                            Text("· \(set.secrets.count)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Duplicar") { state.duplicateSet(set.id) }
                        Divider()
                        Button("Eliminar…", role: .destructive) { pendingDeletion = set }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            AccountFooter()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    state.addSet()
                } label: {
                    Label("Nuevo conjunto", systemImage: "plus")
                }
                .help("Nuevo conjunto de secretos (⌘N)")
            }
        }
        .confirmationDialog(
            "¿Eliminar «\(pendingDeletion?.name ?? "")»?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { set in
            Button("Eliminar", role: .destructive) { state.deleteSet(set.id) }
        } message: { _ in
            Text("Se borrará el conjunto y sus valores guardados en este Mac. Los secretos ya enviados a GitHub no se modifican.")
        }
    }
}

struct AccountFooter: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(state.settings.login.isEmpty ? "Conectado" : state.settings.login)
                    .font(.callout.weight(.medium))
                Text(state.settings.account.isEmpty ? hostName : "\(hostName)/\(state.settings.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Ajustes de conexión (⌘,)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var hostName: String {
        let server = state.settings.serverURL
        return URLComponents(string: server.contains("://") ? server : "https://" + server)?.host ?? server
    }
}
