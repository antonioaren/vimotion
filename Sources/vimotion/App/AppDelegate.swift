import AppKit

/// Application lifecycle: sets up the coordinator and menu bar, checks the
/// Accessibility permission, and applies the persisted state on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let preferences = Preferences()
    private lazy var coordinator = AppCoordinator(preferences: preferences)
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireMenuBar()

        coordinator.onStateChange = { [weak self] in
            self?.menuBar.refresh()
        }

        // Prompt for Accessibility access on first launch.
        if !AccessibilityPermission.ensureTrusted(prompt: true) {
            Log.info("Accessibility permission not yet granted")
        }

        coordinator.start()
        menuBar.refresh()
    }

    private func wireMenuBar() {
        menuBar.stateProvider = { [weak self] in
            guard let self else { return (false, .default, true) }
            return (self.coordinator.isEnabled, self.coordinator.leaderKey, AccessibilityPermission.isTrusted)
        }
        menuBar.onEnable = { [weak self] in self?.coordinator.enable() }
        menuBar.onDisable = { [weak self] in self?.coordinator.disable() }
        menuBar.onSelectLeader = { [weak self] key in self?.coordinator.setLeaderKey(key) }
        menuBar.onShowPermissions = { AccessibilityPermission.openSettings() }
        menuBar.onQuit = { NSApp.terminate(nil) }
    }
}
