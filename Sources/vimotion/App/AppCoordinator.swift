import AppKit

/// Wires the pieces together: a hotkey fires a `Direction`, the coordinator
/// gathers the windows on the active screen, asks the navigator for the target,
/// and focuses it. Also owns the enabled/disabled state and the leader key.
public final class AppCoordinator {

    private let enumerator: WindowEnumerating
    private let navigator: DirectionalNavigator
    private let focuser: WindowFocuser
    private let screenFiltering: ScreenFiltering
    private let hotkeys: HotkeyManaging
    private let preferences: Preferences

    /// Notifies observers (e.g. the menu bar) when state changes.
    public var onStateChange: (() -> Void)?

    public init(
        enumerator: WindowEnumerating = AccessibilityWindowService(),
        navigator: DirectionalNavigator = DirectionalNavigator(),
        focuser: WindowFocuser = WindowFocuser(),
        screenFiltering: ScreenFiltering = ScreenFiltering(),
        hotkeys: HotkeyManaging = CarbonHotkeyManager(),
        preferences: Preferences
    ) {
        self.enumerator = enumerator
        self.navigator = navigator
        self.focuser = focuser
        self.screenFiltering = screenFiltering
        self.hotkeys = hotkeys
        self.preferences = preferences

        self.hotkeys.onDirection = { [weak self] direction in
            self?.navigate(direction)
        }
    }

    // MARK: - State

    public var isEnabled: Bool { preferences.isEnabled }
    public var leaderKey: LeaderKey { preferences.leaderKey }

    /// Applies the persisted state on launch.
    public func start() {
        if preferences.isEnabled {
            hotkeys.register(leader: preferences.leaderKey)
        }
        onStateChange?()
    }

    public func enable() {
        preferences.isEnabled = true
        hotkeys.register(leader: preferences.leaderKey)
        onStateChange?()
    }

    public func disable() {
        preferences.isEnabled = false
        hotkeys.unregister()
        onStateChange?()
    }

    public func setLeaderKey(_ leader: LeaderKey) {
        preferences.leaderKey = leader
        if preferences.isEnabled {
            hotkeys.register(leader: leader) // re-register with the new modifier
        }
        onStateChange?()
    }

    // MARK: - Navigation

    private func navigate(_ direction: Direction) {
        let focused = enumerator.focusedWindow()
        guard let source = focused else {
            Log.debug("No focused window; nothing to navigate from")
            return
        }

        let allWindows = enumerator.onScreenWindows()
        let candidates = screenFiltering.windowsOnActiveScreen(allWindows, focused: source)

        guard let target = navigator.nextWindow(from: source, direction: direction, candidates: candidates) else {
            Log.debug("No window \(direction.rawValue) of focused window")
            return
        }

        focuser.focus(target)
    }
}
