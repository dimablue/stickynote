import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @AppStorage(SettingsKeys.showDockIcon) private var showDockIcon = false
    @AppStorage(SettingsKeys.keepAboveFullScreen) private var keepAboveFullScreen = true
    @AppStorage(SettingsKeys.confirmNoteDeletion) private var confirmNoteDeletion = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    updateLaunchAtLogin(enabled)
                }

            Toggle("Show Dock icon", isOn: $showDockIcon)
                .onChange(of: showDockIcon) { _, enabled in
                    NSApp.setActivationPolicy(enabled ? .regular : .accessory)
                }

            Toggle("Keep Floating Stack above full-screen apps", isOn: $keepAboveFullScreen)
                .onChange(of: keepAboveFullScreen) { _, _ in
                    NotificationCenter.default.post(name: .stickySettingsDidChange, object: nil)
                }

            Toggle("Confirm before deleting nonempty notes", isOn: $confirmNoteDeletion)

            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 470, height: 260)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = error.localizedDescription
        }
    }
}

enum SettingsKeys {
    static let showDockIcon = "showDockIcon"
    static let keepAboveFullScreen = "keepAboveFullScreen"
    static let confirmNoteDeletion = "confirmNoteDeletion"
    static let editorFontSize = "editorFontSize"
    static let floatingWasVisible = "floatingWasVisible"
    static let floatingFrame = "floatingFrame"
    static let floatingLayoutVersion = "floatingLayoutVersion"
}

extension Notification.Name {
    static let stickySettingsDidChange = Notification.Name("stickySettingsDidChange")
}
