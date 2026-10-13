import AppKit
import SwiftUI

struct SecretSetDetailView: View {
    @Environment(AppState.self) private var state
    @Binding var secretSet: SecretSet

    @State private var showImport = false
    @State private var confirmSend = false
    @State private var editing: SecretItem?

    var body: some View {
        Form {
            Section {
                TextField("Nombre del conjunto", text: $secretSet.name, prompt: Text("Ej. Producción API"))
            }

            Section("Destino") {
                LabeledContent("Repositorio") {
                    RepositoryPicker(selection: $secretSet.repository)
                }
                Picker("Tipo de secreto", selection: $secretSet.target) {
                    ForEach(SecretTarget.allCases) { target in
                        Text(target.title).tag(target)
                    }
                }
                if secretSet.target == .environment {
                    TextField("Entorno", text: $secretSet.environment, prompt: Text("production"))
                    Text("Si el entorno no existe en el repositorio, se creará al enviar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach($secretSet.secrets) { $secret in
                    SecretRow(
                        secret: $secret,
                        onEdit: { editing = secret },
                        onDelete: { remove(secret.id) }
                    )
                }
                if secretSet.secrets.isEmpty {
                    Text("Este conjunto no tiene secretos todavía.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("Secretos (\(secretSet.secrets.count))")
                    Spacer()
                    Button {
                        showImport = true
                    } label: {
                        Label("Importar .env", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        secretSet.secrets.append(SecretItem())
                    } label: {
                        Label("Añadir secreto", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderless)
            } footer: {
                Text("Los valores se guardan cifrados en el Llavero de macOS y se cifran con la clave pública del repositorio antes de enviarse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(secretSet.name.isEmpty ? "Sin nombre" : secretSet.name)
        .safeAreaInset(edge: .bottom) {
            sendBar
        }
        .confirmationDialog(
            "¿Enviar \(secretSet.secrets.count) secreto(s) a \(secretSet.repository ?? "")?",
            isPresented: $confirmSend
        ) {
            Button("Enviar") {
                let id = secretSet.id
                Task { await state.upload(setID: id) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Destino: \(destinationDescription). Los secretos que ya existan con el mismo nombre se sobrescribirán.")
        }
        .sheet(isPresented: $showImport) {
            ImportEnvSheet { items in merge(items) }
        }
        .sheet(item: $editing) { item in
            ValueEditorSheet(item: item) { updated in
                if let index = secretSet.secrets.firstIndex(where: { $0.id == updated.id }) {
                    secretSet.secrets[index] = updated
                }
            }
        }
    }

    private var destinationDescription: String {
        secretSet.target == .environment ? "entorno «\(secretSet.environment)»" : secretSet.target.title
    }

    private var sendBar: some View {
        let problems = secretSet.problems
        return HStack(spacing: 12) {
            if let first = problems.first {
                Label(problems.count > 1 ? "\(first) (+\(problems.count - 1))" : first, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .help(problems.joined(separator: "\n"))
            } else if let lastSent = secretSet.lastSentAt {
                Label("Último envío: \(lastSent.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Label("Listo para enviar", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                confirmSend = true
            } label: {
                Label("Enviar secretos", systemImage: "play.fill")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!problems.isEmpty || state.isUploading)
            .help("Cifra y sube todos los secretos al repositorio (⌘↩)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func remove(_ id: SecretItem.ID) {
        secretSet.secrets.removeAll { $0.id == id }
    }

    /// Adds imported secrets, updating the value of those that already exist.
    private func merge(_ items: [SecretItem]) {
        secretSet.secrets.removeAll { $0.name.isEmpty && $0.value.isEmpty }
        for item in items {
            if let index = secretSet.secrets.firstIndex(where: { $0.normalizedName == item.normalizedName }) {
                secretSet.secrets[index].value = item.value
            } else {
                secretSet.secrets.append(item)
            }
        }
    }
}

struct SecretRow: View {
    @Binding var secret: SecretItem
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Nombre", text: $secret.name, prompt: Text("NOMBRE_DEL_SECRETO"))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 230)
                    .onSubmit { secret.name = secret.normalizedName }

                valueField
                    .frame(maxWidth: .infinity)

                Button {
                    reveal.toggle()
                } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                }
                .help(reveal ? "Ocultar valor" : "Mostrar valor")

                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                }
                .help("Editar valor (multilínea)")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help("Quitar secreto")
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .buttonStyle(.borderless)

            if !secret.name.isEmpty, let problem = secret.nameProblem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var valueField: some View {
        if secret.value.contains("\n") {
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "text.alignleft")
                    Text(reveal ? firstLine : "Valor multilínea (\(lineCount) líneas)")
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
        } else if reveal {
            TextField("Valor", text: $secret.value, prompt: Text("valor"))
                .font(.system(.body, design: .monospaced))
        } else {
            SecureField("Valor", text: $secret.value, prompt: Text("valor"))
        }
    }

    private var lineCount: Int {
        secret.value.components(separatedBy: "\n").count
    }

    private var firstLine: String {
        (secret.value.components(separatedBy: "\n").first ?? "") + " …"
    }
}

struct ValueEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: SecretItem
    private let onSave: (SecretItem) -> Void

    init(item: SecretItem, onSave: @escaping (SecretItem) -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editar secreto")
                .font(.title2.bold())
            TextField("Nombre", text: $item.name, prompt: Text("NOMBRE_DEL_SECRETO"))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
            Text("Valor")
                .font(.headline)
            TextEditor(text: $item.value)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                .frame(minHeight: 220)
            HStack {
                Text("Útil para claves privadas, certificados o JSON.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar") {
                    item.name = item.normalizedName
                    onSave(item)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 600, height: 440)
    }
}

struct ImportEnvSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onImport: ([SecretItem]) -> Void

    @State private var text = ""

    private var parsed: [SecretItem] {
        [SecretItem].parseDotEnv(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importar desde .env")
                .font(.title2.bold())
            Text("Pega líneas con el formato CLAVE=valor o abre un archivo. Los secretos que ya existan en el conjunto actualizarán su valor.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                .frame(minHeight: 240)
            HStack {
                Button("Abrir archivo…", action: openFile)
                Text("\(parsed.count) secreto(s) detectado(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Importar") {
                    onImport(parsed)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 600, height: 440)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.message = "Selecciona un archivo .env"
        if panel.runModal() == .OK, let url = panel.url,
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            text = contents
        }
    }
}
