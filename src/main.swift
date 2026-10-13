import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var state = AppState()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.saveNow()
    }
}

@main
struct RepositoryManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Repository Manager", id: "main") {
            ContentView()
                .environment(appDelegate.state)
        }
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo conjunto de secretos") {
                    appDelegate.state.addSet()
                }
                .keyboardShortcut("n")
                .disabled(!appDelegate.state.isConfigured)
            }
        }

        Settings {
            SettingsView()
                .environment(appDelegate.state)
        }
    }
}
