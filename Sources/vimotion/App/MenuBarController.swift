import AppKit

/// Snapshot the menu reads to draw its items and checkmarks.
public struct MenuState {
    public var enabled: Bool
    public var leader: LeaderKey
    public var trusted: Bool
    /// `nil` for development builds.
    public var version: AppVersion?
    public var channel: UpdateChannel
    public var automaticallyChecksForUpdates: Bool
    public var pendingUpdate: AppVersion?
    public var isCheckingForUpdates: Bool
    public var isInstallingUpdate: Bool

    public static let fallback = MenuState(
        enabled: false, leader: .default, trusted: true, version: nil, channel: .default,
        automaticallyChecksForUpdates: true, pendingUpdate: nil,
        isCheckingForUpdates: false, isInstallingUpdate: false
    )
}

/// Owns the menu-bar status item and its menu: the installed version, Enable,
/// Disable, a Leader Key submenu, an Updates submenu, and Quit. Purely
/// presentational — it forwards user intent through closures and reflects state
/// via `refresh`.
public final class MenuBarController: NSObject, NSMenuDelegate {

    public var onEnable: (() -> Void)?
    public var onDisable: (() -> Void)?
    public var onSelectLeader: ((LeaderKey) -> Void)?
    public var onShowPermissions: (() -> Void)?
    public var onCheckForUpdates: (() -> Void)?
    public var onInstallUpdate: (() -> Void)?
    public var onSelectChannel: ((UpdateChannel) -> Void)?
    public var onToggleAutomaticUpdateChecks: (() -> Void)?
    public var onQuit: (() -> Void)?

    public var stateProvider: (() -> MenuState)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    public override init() {
        super.init()
        configureButton()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "vimotion") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "vim"
        }
    }

    /// Refreshes the status item appearance (e.g. dims the icon when disabled).
    public func refresh() {
        guard let state = stateProvider?(), let button = statusItem.button else { return }
        button.alphaValue = state.enabled ? 1.0 : 0.45
    }

    /// "vimotion v1.2.0", "vimotion v1.3.0-beta.4 (Beta)" or "vimotion (development build)".
    static func versionTitle(_ version: AppVersion?) -> String {
        guard let version else { return "vimotion (development build)" }
        return "vimotion v\(version)" + (version.isPrerelease ? " (Beta)" : "")
    }

    // MARK: - NSMenuDelegate

    /// Rebuild the menu each time it opens so checkmarks reflect current state.
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = stateProvider?() ?? .fallback

        let versionItem = NSMenuItem(title: Self.versionTitle(state.version), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        if let pending = state.pendingUpdate {
            let title = state.isInstallingUpdate ? "Installing v\(pending)…" : "Update to v\(pending)…"
            let updateItem = NSMenuItem(title: title, action: #selector(installUpdate), keyEquivalent: "")
            updateItem.target = self
            updateItem.isEnabled = !state.isInstallingUpdate
            menu.addItem(updateItem)
        }

        menu.addItem(.separator())

        if !state.trusted {
            let warning = NSMenuItem(title: "⚠︎ Grant Accessibility access…", action: #selector(showPermissions), keyEquivalent: "")
            warning.target = self
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        let enableItem = NSMenuItem(title: "Enable", action: #selector(enable), keyEquivalent: "")
        enableItem.target = self
        enableItem.state = state.enabled ? .on : .off
        menu.addItem(enableItem)

        let disableItem = NSMenuItem(title: "Disable", action: #selector(disable), keyEquivalent: "")
        disableItem.target = self
        disableItem.state = state.enabled ? .off : .on
        menu.addItem(disableItem)

        menu.addItem(.separator())

        let leaderParent = NSMenuItem(title: "Leader Key", action: nil, keyEquivalent: "")
        let leaderSubmenu = NSMenu()
        for key in LeaderKey.allCases {
            let item = NSMenuItem(title: key.displayName, action: #selector(selectLeader(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key.rawValue
            item.state = (key == state.leader) ? .on : .off
            leaderSubmenu.addItem(item)
        }
        leaderParent.submenu = leaderSubmenu
        menu.addItem(leaderParent)

        let hint = NSMenuItem(title: "Move focus: \(state.leader.displayName) + h/j/k/l", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        let toggleHint = NSMenuItem(title: "Last window: \(state.leader.displayName) + n", action: nil, keyEquivalent: "")
        toggleHint.isEnabled = false
        menu.addItem(toggleHint)

        menu.addItem(.separator())

        let updatesParent = NSMenuItem(title: "Updates", action: nil, keyEquivalent: "")
        updatesParent.submenu = updatesSubmenu(state)
        menu.addItem(updatesParent)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit vimotion", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updatesSubmenu(_ state: MenuState) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let checkTitle = state.isCheckingForUpdates ? "Checking for Updates…" : "Check for Updates…"
        let checkItem = NSMenuItem(title: checkTitle, action: #selector(checkForUpdates), keyEquivalent: "")
        checkItem.target = self
        checkItem.isEnabled = !state.isCheckingForUpdates && !state.isInstallingUpdate
        submenu.addItem(checkItem)

        submenu.addItem(.separator())

        for channel in UpdateChannel.allCases {
            let item = NSMenuItem(title: "\(channel.displayName) Channel", action: #selector(selectChannel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = channel.rawValue
            item.state = (channel == state.channel) ? .on : .off
            item.isEnabled = !state.isInstallingUpdate
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let autoItem = NSMenuItem(title: "Check Automatically", action: #selector(toggleAutomaticChecks), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = state.automaticallyChecksForUpdates ? .on : .off
        submenu.addItem(autoItem)

        return submenu
    }

    // MARK: - Actions

    @objc private func enable() { onEnable?(); refresh() }
    @objc private func disable() { onDisable?(); refresh() }
    @objc private func showPermissions() { onShowPermissions?() }
    @objc private func checkForUpdates() { onCheckForUpdates?() }
    @objc private func installUpdate() { onInstallUpdate?() }
    @objc private func toggleAutomaticChecks() { onToggleAutomaticUpdateChecks?() }
    @objc private func quit() { onQuit?() }

    @objc private func selectLeader(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let key = LeaderKey(rawValue: raw) else { return }
        onSelectLeader?(key)
        refresh()
    }

    @objc private func selectChannel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let channel = UpdateChannel(rawValue: raw) else { return }
        onSelectChannel?(channel)
    }
}
