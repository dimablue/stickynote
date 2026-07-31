import AppKit
import SwiftUI

@main
struct StickyNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showsDock = UserDefaults.standard.bool(forKey: SettingsKeys.showDockIcon)
        NSApp.setActivationPolicy(showsDock ? .regular : .accessory)

        let store = AppStore()
        let actions = AppActions()
        let coordinator = AppCoordinator(store: store, actions: actions)
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.applicationWillTerminate()
    }
}
