import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private static let settingsKey = "settings"

    // Connection
    var settings: AppSettings
    private(set) var token: String = ""
    var isConfigured: Bool { !token.isEmpty }

    // Data
    var secretSets: [SecretSet] = []
    var selectedSetID: SecretSet.ID?
    var repositories: [Repository] = []
    var isLoadingRepositories = false
    var repositoriesError: String?

    // Upload
    var uploadResults: [UploadResult] = []
    var uploadSetName = ""
    var uploadDestination = ""
    var uploadError: String?
    var isUploading = false
    var showUploadSheet = false

    var storageError: String?

    private var saveTask: Task<Void, Never>?
    /// Set when the stored sets could not be read, so they are never overwritten by an empty list.
    private var loadFailed = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = stored
        } else {
            settings = AppSettings()
        }
        do {
            if let data = try KeychainStore.read(KeychainStore.Account.token) {
                token = String(decoding: data, as: UTF8.self)
            }
            if let data = try KeychainStore.read(KeychainStore.Account.secretSets) {
                secretSets = try JSONDecoder().decode([SecretSet].self, from: data)
            }
        } catch {
            loadFailed = true
            storageError = error.localizedDescription
        }
        selectedSetID = secretSets.first?.id
    }

    var client: GitHubClient? {
        guard isConfigured, let baseURL = settings.apiBaseURL else { return nil }
        return GitHubClient(baseURL: baseURL, token: token)
    }

    // MARK: - Connection

    /// Validates the token against the server and stores everything on success.
    func connect(token newToken: String, serverURL: String, account: String) async throws {
        let trimmedToken = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = AppSettings.parseAccount(account)
        var newSettings = settings
        newSettings.serverURL = parsed.server ?? serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.account = parsed.account
        guard let baseURL = newSettings.apiBaseURL else {
            throw GitHubError(statusCode: 0, message: "La URL del servidor no es válida.")
        }
        let user = try await GitHubClient(baseURL: baseURL, token: trimmedToken).currentUser()
        newSettings.login = user.login

        try KeychainStore.write(Data(trimmedToken.utf8), account: KeychainStore.Account.token)
        token = trimmedToken
        settings = newSettings
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
        repositories = []
        await loadRepositories()
    }

    func disconnect() {
        try? KeychainStore.delete(KeychainStore.Account.token)
        token = ""
        repositories = []
        settings.login = ""
    }

    // MARK: - Repositories

    func loadRepositories() async {
        guard let client else { return }
        isLoadingRepositories = true
        repositoriesError = nil
        defer { isLoadingRepositories = false }
        do {
            let owner = settings.account.isEmpty ? nil : settings.account
            repositories = try await client.repositories(owner: owner)
        } catch {
            repositoriesError = error.localizedDescription
        }
    }

    // MARK: - Secret sets

    func addSet() {
        var name = "Nuevo conjunto"
        var counter = 2
        while secretSets.contains(where: { $0.name == name }) {
            name = "Nuevo conjunto \(counter)"
            counter += 1
        }
        let set = SecretSet(name: name, secrets: [SecretItem()])
        secretSets.append(set)
        selectedSetID = set.id
    }

    func duplicateSet(_ id: SecretSet.ID) {
        guard let original = secretSets.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.name = original.name + " (copia)"
        copy.secrets = original.secrets.map { SecretItem(name: $0.name, value: $0.value) }
        copy.lastSentAt = nil
        secretSets.append(copy)
        selectedSetID = copy.id
    }

    func deleteSet(_ id: SecretSet.ID) {
        secretSets.removeAll { $0.id == id }
        if selectedSetID == id {
            selectedSetID = secretSets.first?.id
        }
    }

    /// Persists the secret sets to the Keychain shortly after the last change.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        guard !loadFailed else {
            storageError = "Los conjuntos guardados no se pudieron leer del Llavero, así que los cambios no se guardarán para no sobrescribirlos. Reinicia la app y permite el acceso al Llavero."
            return
        }
        do {
            let data = try JSONEncoder().encode(secretSets)
            try KeychainStore.write(data, account: KeychainStore.Account.secretSets)
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    // MARK: - Upload

    func upload(setID: SecretSet.ID) async {
        guard let client, let set = secretSets.first(where: { $0.id == setID }), let repository = set.repository else {
            return
        }
        let environment = set.environment.trimmingCharacters(in: .whitespaces)
        uploadSetName = set.name
        uploadDestination = "\(repository) · \(set.target == .environment ? "entorno \(environment)" : set.target.title)"
        uploadResults = set.secrets.map { UploadResult(id: $0.id, name: $0.normalizedName) }
        uploadError = nil
        isUploading = true
        showUploadSheet = true
        defer { isUploading = false }

        let key: RepositoryPublicKey
        do {
            if set.target == .environment {
                try await client.ensureEnvironment(repository: repository, name: environment)
            }
            key = try await client.publicKey(repository: repository, target: set.target, environment: environment)
        } catch {
            uploadError = error.localizedDescription
            for index in uploadResults.indices {
                uploadResults[index].status = .failed("No se envió")
            }
            return
        }

        var allSucceeded = true
        for (index, secret) in set.secrets.enumerated() {
            uploadResults[index].status = .running
            do {
                let result = try await client.putSecret(
                    name: secret.normalizedName,
                    value: secret.value,
                    publicKey: key,
                    repository: repository,
                    target: set.target,
                    environment: environment
                )
                uploadResults[index].status = result == .created ? .created : .updated
            } catch {
                allSucceeded = false
                uploadResults[index].status = .failed(error.localizedDescription)
            }
        }

        if allSucceeded, let index = secretSets.firstIndex(where: { $0.id == setID }) {
            secretSets[index].lastSentAt = Date()
            saveNow()
        }
    }
}
