import CoreGraphics
import Foundation

/// A value type describing an on-screen window. Pure data, no system handles,
/// so the navigation core stays free of side effects and is fully testable.
///
/// `frame` uses the **top-left origin** convention (y grows downward), matching
/// the output of `CGWindowListCopyWindowInfo`.
public struct WindowInfo: Equatable, Sendable {
    /// The Core Graphics window id (stable while the window exists).
    public let id: CGWindowID
    /// Owning process id.
    public let pid: pid_t
    /// Window rectangle in global, top-left-origin screen coordinates.
    public let frame: CGRect
    /// Best-effort window title (may be empty).
    public let title: String
    /// Owning application name (may be empty).
    public let appName: String

    public init(
        id: CGWindowID,
        pid: pid_t,
        frame: CGRect,
        title: String = "",
        appName: String = ""
    ) {
        self.id = id
        self.pid = pid
        self.frame = frame
        self.title = title
        self.appName = appName
    }

    /// Geometric center of the window.
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
