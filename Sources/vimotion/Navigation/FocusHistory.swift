import CoreGraphics

/// Tracks the last two focused windows so the toggle shortcut can jump back to
/// the previously visited one. Pure data, no system handles, so it is fully
/// testable like `DirectionalNavigator`.
public final class FocusHistory {

    /// The most recently focused window, if any was recorded.
    public private(set) var current: WindowInfo?
    /// The window focused before `current`, if any.
    public private(set) var previous: WindowInfo?

    public init() {}

    /// Records a focus change. Recording the same window id again only
    /// refreshes `current` (frame/title may have changed) without clobbering
    /// `previous`, which absorbs duplicate activation notifications.
    public func record(_ window: WindowInfo) {
        if window.id == current?.id {
            current = window
            return
        }
        previous = current
        current = window
    }

    /// The window to toggle to: the previous one, never the caller's current
    /// window. Returns nil when there is nothing to go back to.
    public func toggleTarget(currentID: CGWindowID?) -> WindowInfo? {
        guard let previous, previous.id != currentID else { return nil }
        return previous
    }

    /// Forgets the previous window (e.g. when it turned out to be closed).
    public func dropPrevious() {
        previous = nil
    }
}
