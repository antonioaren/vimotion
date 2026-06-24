import AppKit
import CoreGraphics

/// Enumerates on-screen windows using `CGWindowListCopyWindowInfo` and resolves
/// the focused window via the frontmost application.
///
/// Coordinates returned are in the global, top-left-origin space used by
/// CoreGraphics, matching `WindowInfo`'s convention.
public struct AccessibilityWindowService: WindowEnumerating {

    /// Minimum width/height for a window to be considered (filters out tiny
    /// helper/utility windows).
    private let minimumSize: CGFloat

    /// PID of this process, excluded from results.
    private let ownPID: pid_t

    public init(minimumSize: CGFloat = 48) {
        self.minimumSize = minimumSize
        self.ownPID = ProcessInfo.processInfo.processIdentifier
    }

    public func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return raw.compactMap { entry -> WindowInfo? in
            // Normal window layer only (0). Skip menus, the Dock, overlays, etc.
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else {
                return nil
            }
            // Skip fully transparent windows.
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha <= 0.01 {
                return nil
            }
            guard
                let windowNumber = entry[kCGWindowNumber as String] as? Int,
                let pid = entry[kCGWindowOwnerPID as String] as? Int,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else {
                return nil
            }

            let pidValue = pid_t(pid)
            if pidValue == ownPID { return nil }
            if frame.width < minimumSize || frame.height < minimumSize { return nil }

            let title = entry[kCGWindowName as String] as? String ?? ""
            let appName = entry[kCGWindowOwnerName as String] as? String ?? ""

            return WindowInfo(
                id: CGWindowID(windowNumber),
                pid: pidValue,
                frame: frame,
                title: title,
                appName: appName
            )
        }
    }

    public func focusedWindow() -> WindowInfo? {
        let windows = onScreenWindows()
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            // Fallback: the front-most window overall.
            return windows.first
        }
        // CGWindowList is front-to-back, so the first window owned by the
        // frontmost app is its focused/key window.
        return windows.first(where: { $0.pid == frontPID }) ?? windows.first
    }
}
