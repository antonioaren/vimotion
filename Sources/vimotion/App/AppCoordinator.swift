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
    private let history: FocusHistory
    private let focusObserver: FocusObserving

    /// Notifies observers (e.g. the menu bar) when state changes.
    public var onStateChange: (() -> Void)?

    public init(
        enumerator: WindowEnumerating = AccessibilityWindowService(),
        navigator: DirectionalNavigator = DirectionalNavigator(),
        focuser: WindowFocuser = WindowFocuser(),
        screenFiltering: ScreenFiltering = ScreenFiltering(),
        hotkeys: HotkeyManaging = CarbonHotkeyManager(),
        preferences: Preferences,
        history: FocusHistory = FocusHistory(),
        focusObserver: FocusObserving = WorkspaceFocusObserver()
    ) {
        self.enumerator = enumerator
        self.navigator = navigator
        self.focuser = focuser
        self.screenFiltering = screenFiltering
        self.hotkeys = hotkeys
        self.preferences = preferences
        self.history = history
        self.focusObserver = focusObserver

        self.hotkeys.onAction = { [weak self] action in
            switch action {
            case .navigate(let direction):
                self?.navigate(direction)
            case .toggleLastWindow:
                self?.toggleLastWindow()
            }
        }

        self.focusObserver.onFocusChange = { [weak self] in
            guard let self, let focused = self.enumerator.focusedWindow() else { return }
            self.history.record(focused)
        }
    }

    // MARK: - State

    public var isEnabled: Bool { preferences.isEnabled }
    public var leaderKey: LeaderKey { preferences.leaderKey }

    /// Applies the persisted state on launch.
    public func start() {
        // Track focus even while hotkeys are disabled so the toggle history is
        // already warm when the user re-enables them.
        focusObserver.start()
        if let focused = enumerator.focusedWindow() {
            history.record(focused)
        }
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

        // Record around the focus change so same-app moves (which the
        // workspace notification misses) still feed the toggle history.
        history.record(source)
        focuser.focus(target)
        history.record(target)
    }

    /// Toggles focus between the current window and the last visited one.
    private func toggleLastWindow() {
        let focused = enumerator.focusedWindow()
        if let focused {
            history.record(focused)
        }

        guard let target = history.toggleTarget(currentID: focused?.id) else {
            Log.debug("No previous window to toggle to")
            return
        }

        // Re-resolve by id so the focuser works with the window's live frame.
        guard let live = enumerator.onScreenWindows().first(where: { $0.id == target.id }) else {
            Log.debug("Previous window \(target.id) is gone; dropping it")
            history.dropPrevious()
            return
        }

        focuser.focus(live)
        history.record(live) // swap → toggling twice returns to the original
    }
}
