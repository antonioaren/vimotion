import Foundation

/// Abstraction over the source of on-screen windows, so the rest of the app can
/// depend on a protocol (and be tested with mocks) rather than on the
/// Accessibility / CoreGraphics APIs directly.
public protocol WindowEnumerating {
    /// All eligible on-screen windows, in front-to-back z-order.
    func onScreenWindows() -> [WindowInfo]

    /// The currently focused window, if it can be determined.
    func focusedWindow() -> WindowInfo?
}
