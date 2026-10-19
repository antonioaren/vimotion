import AppKit

/// Wires the pieces together: a hotkey fires a `Direction`, the coordinator
/// gathers the windows on the active screen, asks the navigator for the target,
/// and focuses it. When nothing lies in that direction on the active screen, it
/// jumps to the adjacent display instead. Also owns the enabled/disabled state,
/// the leader key and the current display layout.
public final class AppCoordinator {

    private let enumerator: WindowEnumerating
    private let navigator: DirectionalNavigator
    private let focuser: WindowFocuser
    private let screenFiltering: ScreenFiltering
    private let hotkeys: HotkeyManaging
    private let preferences: Preferences
    private let history: FocusHistory
    private let focusObserver: FocusObserving
    private let screenObserver: ScreenChangeObserving
    private let screenMemory: ScreenFocusMemory

    /// Display arrangement, refreshed whenever a monitor is connected,
    /// disconnected or rearranged.
    public private(set) var layout: DisplayLayout

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
        focusObserver: FocusObserving = WorkspaceFocusObserver(),
        screenObserver: ScreenChangeObserving = ScreenChangeObserver(),
        screenMemory: ScreenFocusMemory = ScreenFocusMemory()
    ) {
        self.enumerator = enumerator
        self.navigator = navigator
        self.focuser = focuser
        self.screenFiltering = screenFiltering
        self.hotkeys = hotkeys
        self.preferences = preferences
        self.history = history
        self.focusObserver = focusObserver
        self.screenObserver = screenObserver
        self.screenMemory = screenMemory
        self.layout = screenFiltering.currentLayout()

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
            self.remember(focused)
        }

        self.screenObserver.onScreensChange = { [weak self] in
            self?.reloadDisplays()
        }
    }

    // MARK: - State

    public var isEnabled: Bool { preferences.isEnabled }
    public var leaderKey: LeaderKey { preferences.leaderKey }

    /// Applies the persisted state on launch.
    public func start() {
        screenObserver.start()
        reloadDisplays()

        // Track focus even while hotkeys are disabled so the toggle history is
        // already warm when the user re-enables them.
        focusObserver.start()
        if let focused = enumerator.focusedWindow() {
            remember(focused)
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

    // MARK: - Displays

    /// Re-reads the display arrangement from macOS and forgets displays that
    /// are no longer connected.
    public func reloadDisplays() {
        layout = screenFiltering.currentLayout()
        screenMemory.prune(keeping: Set(layout.displays.map(\.id)))
        Log.info("Display layout: \(layout.summary)")
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
        let active = screenFiltering.activeDisplay(focused: source, in: layout)
        let candidates = active.map { screenFiltering.windows(allWindows, on: $0) } ?? allWindows

        if let target = navigator.nextWindow(from: source, direction: direction, candidates: candidates) {
            move(from: source, to: target)
            return
        }

        guard let activeDisplay = active,
              let neighbor = layout.neighbor(of: activeDisplay, direction: direction) else {
            Log.debug("No window or display \(direction.rawValue) of focused window")
            return
        }

        let neighborWindows = screenFiltering.windows(allWindows, on: neighbor)
        guard let target = preferredWindow(on: neighbor, among: neighborWindows) else {
            Log.debug("Display \(neighbor.name) has no windows to focus")
            return
        }
        move(from: source, to: target)
    }

    /// The window to land on when entering `display`: the last one focused
    /// there if it is still open on that display, otherwise the frontmost.
    private func preferredWindow(on display: DisplayInfo, among windows: [WindowInfo]) -> WindowInfo? {
        if let last = screenMemory.lastWindow(on: display.id),
           let live = windows.first(where: { $0.id == last.id }) {
            return live
        }
        return windows.first
    }

    private func move(from source: WindowInfo, to target: WindowInfo) {
        // Record around the focus change so same-app moves (which the
        // workspace notification misses) still feed the toggle history.
        remember(source)
        focuser.focus(target)
        remember(target)
    }

    /// Feeds both the toggle history and the per-display focus memory.
    private func remember(_ window: WindowInfo) {
        history.record(window)
        if let display = layout.display(containing: window.center) {
            screenMemory.record(window, on: display.id)
        }
    }

    /// Toggles focus between the current window and the last visited one.
    private func toggleLastWindow() {
        let focused = enumerator.focusedWindow()
        if let focused {
            remember(focused)
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
        remember(live) // swap → toggling twice returns to the original
    }
}
