import CoreGraphics

/// Remembers the last focused window on each display, so moving to another
/// display lands on the window you were using there. Pure data, no system
/// handles, so it is fully testable like `FocusHistory`.
public final class ScreenFocusMemory {

    private var lastWindows: [CGDirectDisplayID: WindowInfo] = [:]

    public init() {}

    /// Records `window` as the most recently focused one on `displayID`.
    public func record(_ window: WindowInfo, on displayID: CGDirectDisplayID) {
        lastWindows[displayID] = window
    }

    /// The last focused window on `displayID`, if any was recorded.
    public func lastWindow(on displayID: CGDirectDisplayID) -> WindowInfo? {
        lastWindows[displayID]
    }

    /// Forgets the window remembered for `displayID`.
    public func forget(displayID: CGDirectDisplayID) {
        lastWindows[displayID] = nil
    }

    /// Drops every display not in `displayIDs` (e.g. after a monitor was
    /// disconnected).
    public func prune(keeping displayIDs: Set<CGDirectDisplayID>) {
        lastWindows = lastWindows.filter { displayIDs.contains($0.key) }
    }
}
