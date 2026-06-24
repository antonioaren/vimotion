import AppKit

/// Supplies display geometry in the global, top-left-origin (CoreGraphics)
/// coordinate space. Abstracted so the filtering logic can be unit-tested.
public protocol ScreenProviding {
    /// Frames of all displays, in top-left-origin coordinates.
    var screenFramesCG: [CGRect] { get }
    /// Current mouse location, in top-left-origin coordinates.
    var mouseLocationCG: CGPoint { get }
}

/// Default implementation backed by `NSScreen` / `NSEvent`, converting from
/// Cocoa's bottom-left coordinate space to CoreGraphics' top-left space.
public struct NSScreenProvider: ScreenProviding {
    public init() {}

    /// Height of the primary display (the one whose Cocoa origin is (0,0)),
    /// used to flip the vertical axis.
    private var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    public var screenFramesCG: [CGRect] {
        let h = primaryHeight
        return NSScreen.screens.map { screen in
            let f = screen.frame
            return CGRect(x: f.origin.x, y: h - f.origin.y - f.height, width: f.width, height: f.height)
        }
    }

    public var mouseLocationCG: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }
}

/// Restricts a set of windows to those on the "active" display, where the active
/// display is the one containing the focused window (or, as a fallback, the
/// mouse cursor).
public struct ScreenFiltering {

    private let screens: ScreenProviding

    public init(screens: ScreenProviding = NSScreenProvider()) {
        self.screens = screens
    }

    /// Frame (top-left coords) of the active display, or `nil` if it can't be
    /// determined.
    public func activeScreenFrame(focused: WindowInfo?) -> CGRect? {
        let frames = screens.screenFramesCG
        guard !frames.isEmpty else { return nil }

        let referencePoint = focused?.center ?? screens.mouseLocationCG
        if let match = frames.first(where: { $0.contains(referencePoint) }) {
            return match
        }
        // Fallback: the display whose center is nearest the reference point.
        return frames.min(by: { lhs, rhs in
            distance(from: center(of: lhs), to: referencePoint) <
            distance(from: center(of: rhs), to: referencePoint)
        })
    }

    /// Returns only the windows whose center lies on the active display. If the
    /// active display can't be determined, all windows are returned unchanged.
    public func windowsOnActiveScreen(_ windows: [WindowInfo], focused: WindowInfo?) -> [WindowInfo] {
        guard let active = activeScreenFrame(focused: focused) else { return windows }
        return windows.filter { active.contains($0.center) }
    }

    // MARK: - Helpers

    private func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
