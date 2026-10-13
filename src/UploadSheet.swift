import SwiftUI

struct UploadSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.uploadSetName)
                        .font(.headline)
                    Text(state.uploadDestination)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = state.uploadError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            List(state.uploadResults) { result in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    icon(for: result.status)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name)
                            .font(.system(.body, design: .monospaced))
                        if case .failed(let message) = result.status {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Text(label(for: result.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            HStack {
                if state.isUploading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Enviando…")
                        .foregroundStyle(.secondary)
                } else {
                    Text(summary)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.isUploading)
            }
        }
        .padding(20)
        .frame(width: 540, height: 440)
        .interactiveDismissDisabled(state.isUploading)
    }

    private var summary: String {
        var created = 0, updated = 0, failed = 0
        for result in state.uploadResults {
            switch result.status {
            case .created: created += 1
            case .updated: updated += 1
            case .failed: failed += 1
            default: break
            }
        }
        var parts: [String] = []
        if created > 0 { parts.append("\(created) creado(s)") }
        if updated > 0 { parts.append("\(updated) actualizado(s)") }
        if failed > 0 { parts.append("\(failed) con error") }
        return parts.isEmpty ? "Sin cambios" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func icon(for status: UploadResult.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .created, .updated:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func label(for status: UploadResult.Status) -> String {
        switch status {
        case .pending: "Pendiente"
        case .running: "Enviando"
        case .created: "Creado"
        case .updated: "Actualizado"
        case .failed: "Error"
        }
    }
}
