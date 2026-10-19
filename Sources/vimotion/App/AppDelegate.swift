import AppKit

/// Application lifecycle: sets up the coordinator, updater and menu bar, checks
/// the Accessibility permission, and applies the persisted state on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let preferences = Preferences()
    private lazy var coordinator = AppCoordinator(preferences: preferences)
    private lazy var updater = UpdateController(
        preferences: preferences,
        prompter: AlertUpdatePrompter(),
        installer: UpdateInstaller()
    )
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireMenuBar()

        coordinator.onStateChange = { [weak self] in
            self?.menuBar.refresh()
        }
        updater.onStateChange = { [weak self] in
            self?.menuBar.refresh()
        }

        // Prompt for Accessibility access on first launch.
        if !AccessibilityPermission.ensureTrusted(prompt: true) {
            Log.info("Accessibility permission not yet granted")
        }

        coordinator.start()
        updater.start()
        menuBar.refresh()
    }

    private func wireMenuBar() {
        menuBar.stateProvider = { [weak self] in
            guard let self else { return .fallback }
            return MenuState(
                enabled: self.coordinator.isEnabled,
                leader: self.coordinator.leaderKey,
                trusted: AccessibilityPermission.isTrusted,
                displays: self.coordinator.layout.summary,
                version: self.updater.currentVersion,
                channel: self.updater.channel,
                automaticallyChecksForUpdates: self.updater.automaticallyChecks,
                pendingUpdate: self.updater.pendingUpdate?.release?.version,
                isCheckingForUpdates: self.updater.isChecking,
                isInstallingUpdate: self.updater.isInstalling
            )
        }
        menuBar.onEnable = { [weak self] in self?.coordinator.enable() }
        menuBar.onDisable = { [weak self] in self?.coordinator.disable() }
        menuBar.onSelectLeader = { [weak self] key in self?.coordinator.setLeaderKey(key) }
        menuBar.onShowPermissions = { AccessibilityPermission.openSettings() }
        menuBar.onCheckForUpdates = { [weak self] in self?.updater.checkForUpdates(userInitiated: true) }
        menuBar.onInstallUpdate = { [weak self] in self?.updater.installPendingUpdate() }
        menuBar.onSelectChannel = { [weak self] channel in self?.updater.setChannel(channel) }
        menuBar.onToggleAutomaticUpdateChecks = { [weak self] in
            guard let self else { return }
            self.updater.setAutomaticallyChecks(!self.updater.automaticallyChecks)
        }
        menuBar.onQuit = { NSApp.terminate(nil) }
    }
}
