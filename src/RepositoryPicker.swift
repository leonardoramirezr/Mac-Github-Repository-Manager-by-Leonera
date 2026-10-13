import SwiftUI

/// Button that opens a searchable list of the account's repositories.
struct RepositoryPicker: View {
    @Environment(AppState.self) private var state
    @Binding var selection: String?

    @State private var isPresented = false
    @State private var query = ""

    var body: some View {
        Button {
            query = ""
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                Text(selection ?? "Seleccionar repositorio…")
                    .foregroundStyle(selection == nil ? Color.secondary : Color.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
                .frame(width: 400, height: 440)
        }
    }

    private var filtered: [Repository] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return state.repositories }
        return state.repositories.filter { $0.fullName.localizedCaseInsensitiveContains(text) }
    }

    /// Lets the user type "owner/repo" for repositories missing from the list.
    private var manualEntry: String? {
        let text = query.trimmingCharacters(in: .whitespaces)
        let parts = text.split(separator: "/")
        guard parts.count == 2, !text.contains(" ") else { return nil }
        let exists = state.repositories.contains { $0.fullName.caseInsensitiveCompare(text) == .orderedSame }
        return exists ? nil : text
    }

    private var popoverContent: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar o escribir propietario/repositorio", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if let manualEntry {
                            choose(manualEntry)
                        } else if filtered.count == 1, let only = filtered.first {
                            choose(only.fullName)
                        }
                    }
                if state.isLoadingRepositories {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await state.loadRepositories() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Recargar repositorios")
                }
            }
            .padding(10)

            Divider()

            if let error = state.repositoriesError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            List {
                if let manualEntry {
                    Button {
                        choose(manualEntry)
                    } label: {
                        Label("Usar «\(manualEntry)»", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderless)
                }
                ForEach(filtered) { repository in
                    Button {
                        choose(repository.fullName)
                    } label: {
                        HStack {
                            Image(systemName: repository.isPrivate ? "lock" : "book.closed")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(repository.fullName)
                            Spacer()
                            if repository.fullName == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if filtered.isEmpty && manualEntry == nil && !state.isLoadingRepositories {
                    Text(state.repositories.isEmpty ? "No hay repositorios cargados." : "Sin resultados.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
            Text("\(state.repositories.count) repositorios\(state.settings.account.isEmpty ? "" : " de \(state.settings.account)")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    private func choose(_ fullName: String) {
        selection = fullName
        isPresented = false
    }
}
