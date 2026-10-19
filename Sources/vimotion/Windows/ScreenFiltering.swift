import AppKit

/// Supplies display geometry in the global, top-left-origin (CoreGraphics)
/// coordinate space. Abstracted so the filtering logic can be unit-tested.
public protocol ScreenProviding {
    /// All connected displays, in top-left-origin coordinates.
    var displays: [DisplayInfo] { get }
    /// Current mouse location, in top-left-origin coordinates.
    var mouseLocationCG: CGPoint { get }
}

public extension ScreenProviding {
    /// Frames of all displays, in top-left-origin coordinates.
    var screenFramesCG: [CGRect] { displays.map(\.frame) }
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

    public var displays: [DisplayInfo] {
        let h = primaryHeight
        // `NSScreen.screens.first` is always the primary display.
        return NSScreen.screens.enumerated().map { index, screen in
            let f = screen.frame
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return DisplayInfo(
                id: number?.uint32Value ?? CGDirectDisplayID(index),
                frame: CGRect(x: f.origin.x, y: h - f.origin.y - f.height, width: f.width, height: f.height),
                isPrimary: index == 0,
                name: screen.localizedName
            )
        }
    }

    public var mouseLocationCG: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }
}

/// Restricts a set of windows to those on a given display, where the "active"
/// display is the one containing the focused window (or, as a fallback, the
/// mouse cursor).
public struct ScreenFiltering {

    private let screens: ScreenProviding

    public init(screens: ScreenProviding = NSScreenProvider()) {
        self.screens = screens
    }

    /// Snapshot of the current display arrangement.
    public func currentLayout() -> DisplayLayout {
        DisplayLayout(displays: screens.displays)
    }

    /// The active display within `layout`, or `nil` if there are no displays.
    public func activeDisplay(focused: WindowInfo?, in layout: DisplayLayout) -> DisplayInfo? {
        layout.display(containing: focused?.center ?? screens.mouseLocationCG)
    }

    /// Frame (top-left coords) of the active display, or `nil` if it can't be
    /// determined.
    public func activeScreenFrame(focused: WindowInfo?) -> CGRect? {
        activeDisplay(focused: focused, in: currentLayout())?.frame
    }

    /// Returns only the windows whose center lies on `display`, preserving
    /// their order (front-to-back when coming from `WindowEnumerating`).
    public func windows(_ windows: [WindowInfo], on display: DisplayInfo) -> [WindowInfo] {
        windows.filter { display.frame.contains($0.center) }
    }

    /// Returns only the windows whose center lies on the active display. If the
    /// active display can't be determined, all windows are returned unchanged.
    public func windowsOnActiveScreen(_ windows: [WindowInfo], focused: WindowInfo?) -> [WindowInfo] {
        guard let active = activeDisplay(focused: focused, in: currentLayout()) else { return windows }
        return self.windows(windows, on: active)
    }
}
