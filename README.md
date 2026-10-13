# Repository Manager

A native macOS app to upload **many GitHub secrets to a repository in one click**.

Define reusable *secret sets* (a group of secrets plus the repository they belong to), pick a repository from your account and press **Enviar secretos** — every secret is encrypted with the repository's public key and uploaded through the GitHub REST API.

Built from [mac-app-template](https://github.com/leonardoramirezr/mac-app-template): Swift + SwiftUI, no Xcode project and no third-party dependencies — just `swiftc`, a `Makefile` and a shell script.

> The user interface is in Spanish.

## Features

- **First-run setup**: enter a Personal Access Token (fine-grained or classic), the GitHub server URL (github.com or GitHub Enterprise Server) and, optionally, an account or organization (name or URL such as `https://github.com/my-org`) to filter the repository list. The token is validated against the API before being saved.
- **Secret sets**: create, rename, duplicate and delete sets. Each set holds:
  - any number of secrets (name + value, hidden by default, multi-line values supported),
  - the target repository (searchable list of the repositories your token can see, or type `owner/repo`),
  - the secret type: **Actions**, **Dependabot**, **Codespaces** or an Actions **environment** (created automatically if it does not exist).
- **Import from `.env`**: paste `KEY=value` lines or open a `.env` file; existing secrets are updated.
- **Validation** of secret names with GitHub's rules (letters, digits and `_`, not starting with a digit or `GITHUB_`, no duplicates).
- **One-click upload** (`⌘↩`) with per-secret progress, showing which secrets were created, updated or failed.

## Security

- The token **and the secret sets (including their values)** are stored in the macOS Keychain, never in plain files or `UserDefaults`. Only non-sensitive connection settings (server URL, account, login) live in `UserDefaults`.
- Values are encrypted locally with a libsodium-compatible *sealed box* (`crypto_box_seal`: X25519 + XSalsa20-Poly1305) using the repository's public key, as [required by GitHub](https://docs.github.com/en/rest/guides/encrypting-secrets-for-the-rest-api). X25519 comes from CryptoKit; XSalsa20, Poly1305 and BLAKE2b are implemented in `src/SealedBox.swift` and checked against libsodium test vectors (`make test`).
- The token is only sent to the configured GitHub API host.

Because the app is ad-hoc signed, macOS may ask for permission to read the Keychain items again after each rebuild. Choose *Always Allow*.

## Token permissions

| Token type   | Permissions needed |
|--------------|--------------------|
| Fine-grained | Repository access to the target repositories, **Secrets: Read and write** (plus **Dependabot secrets**, **Codespaces secrets** or **Environments: Read and write** if you use those types). *Metadata: Read* is included automatically. |
| Classic      | `repo` scope (`public_repo` is enough for public repositories only). |

## Requirements

- macOS 15.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & install

```sh
make build     # builds build/RepositoryManager.app
make install   # builds and copies it into /Applications
make test      # runs the encryption tests
```

Every push also builds the app on GitHub Actions (`.github/workflows/build.yml`) and uploads it as a zipped artifact. A downloaded build is quarantined by macOS; building locally avoids that (or run `xattr -dr com.apple.quarantine RepositoryManager.app`).

## Project structure

```
.
├── src/
│   ├── main.swift                # App entry point, window, menu commands, Settings scene
│   ├── AppState.swift            # Observable app state: connection, sets, upload flow
│   ├── Models.swift              # SecretSet, SecretItem, settings, .env parsing, validation
│   ├── GitHubClient.swift        # GitHub REST API client
│   ├── SealedBox.swift           # libsodium-compatible sealed box (GitHub secret encryption)
│   ├── KeychainStore.swift       # Keychain persistence
│   ├── ContentView.swift         # Main window: sidebar and detail
│   ├── SecretSetDetailView.swift # Set editor, secret rows, .env import, value editor
│   ├── RepositoryPicker.swift    # Searchable repository popover
│   ├── UploadSheet.swift         # Upload progress and results
│   └── ConnectionViews.swift     # Onboarding and Settings
├── tests/SealedBoxTests.swift    # Encryption test vectors
├── Resources/Icon/AppIcon.icns   # Optional app icon (copied if present)
├── Info.plist
├── build.sh
└── Makefile
```

## License

This project is licensed under the terms of the [GNU General Public License v3.0](LICENSE).
