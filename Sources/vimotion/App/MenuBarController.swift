import AppKit

/// Owns the menu-bar status item and its menu: Enable, Disable, a Leader Key
/// submenu, and Quit. Purely presentational — it forwards user intent through
/// closures and reflects state via `refresh`.
public final class MenuBarController: NSObject, NSMenuDelegate {

    public var onEnable: (() -> Void)?
    public var onDisable: (() -> Void)?
    public var onSelectLeader: ((LeaderKey) -> Void)?
    public var onShowPermissions: (() -> Void)?
    public var onQuit: (() -> Void)?

    /// Snapshot the menu reads to draw checkmarks.
    public var stateProvider: (() -> (enabled: Bool, leader: LeaderKey, trusted: Bool))?

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

    // MARK: - NSMenuDelegate

    /// Rebuild the menu each time it opens so checkmarks reflect current state.
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = stateProvider?() ?? (enabled: false, leader: .default, trusted: true)

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

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit vimotion", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func enable() { onEnable?(); refresh() }
    @objc private func disable() { onDisable?(); refresh() }
    @objc private func showPermissions() { onShowPermissions?() }
    @objc private func quit() { onQuit?() }

    @objc private func selectLeader(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let key = LeaderKey(rawValue: raw) else { return }
        onSelectLeader?(key)
        refresh()
    }
}
