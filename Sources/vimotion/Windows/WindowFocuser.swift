import AppKit
import ApplicationServices

/// Gives keyboard focus to a target window: it activates the owning application
/// and raises the matching window via the Accessibility API.
public struct WindowFocuser {

    public init() {}

    /// Focuses `target`. Returns `true` if the window was raised successfully.
    @discardableResult
    public func focus(_ target: WindowInfo) -> Bool {
        let appElement = AXUIElementCreateApplication(target.pid)

        guard let axWindow = matchingAXWindow(in: appElement, frame: target.frame) else {
            // As a fallback, at least bring the owning app forward.
            activateApp(pid: target.pid)
            Log.error("Could not match AX window for id=\(target.id); activated app only")
            return false
        }

        // Mark as main and raise, then activate the app so it receives keys.
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raiseResult = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        activateApp(pid: target.pid)

        return raiseResult == .success
    }

    // MARK: - AX helpers

    private func activateApp(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// Finds the application's AX window whose frame best matches `frame`.
    private func matchingAXWindow(in appElement: AXUIElement, frame: CGRect) -> AXUIElement? {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else {
            return nil
        }

        var best: AXUIElement?
        var bestDelta = CGFloat.greatestFiniteMagnitude
        for window in windows {
            guard let windowFrame = frameOf(window) else { continue }
            let delta = frameDistance(windowFrame, frame)
            if delta < bestDelta {
                bestDelta = delta
                best = window
            }
        }
        // Return the closest frame match (the CG and AX frames of the same
        // window line up within a couple of points in practice).
        return best
    }

    private func frameOf(_ window: AXUIElement) -> CGRect? {
        guard
            let position = axValue(window, kAXPositionAttribute, type: .cgPoint, as: CGPoint.self),
            let size = axValue(window, kAXSizeAttribute, type: .cgSize, as: CGSize.self)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func frameDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.origin.x - b.origin.x) + abs(a.origin.y - b.origin.y)
            + abs(a.width - b.width) + abs(a.height - b.height)
    }

    /// Reads an `AXValue`-wrapped geometry attribute and unwraps it.
    private func axValue<T>(_ element: AXUIElement, _ attribute: String, type: AXValueType, as: T.Type) -> T? {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let axVal = raw, CFGetTypeID(axVal) == AXValueGetTypeID() else {
            return nil
        }
        let axValueRef = axVal as! AXValue
        let result = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { result.deallocate() }
        if AXValueGetValue(axValueRef, type, result) {
            return result.pointee
        }
        return nil
    }
}
