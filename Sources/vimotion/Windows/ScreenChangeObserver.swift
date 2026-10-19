import AppKit

/// Abstraction over display configuration changes (connecting, disconnecting
/// or rearranging monitors), so the coordinator can be tested with a mock.
public protocol ScreenChangeObserving: AnyObject {
    /// Called on the main thread whenever the display configuration changes.
    var onScreensChange: (() -> Void)? { get set }

    /// Starts observing display changes. Idempotent.
    func start()

    /// Stops observing display changes.
    func stop()
}

/// Observes `NSApplication.didChangeScreenParametersNotification`, which fires
/// after `NSScreen.screens` reflects the new arrangement.
public final class ScreenChangeObserver: ScreenChangeObserving {

    public var onScreensChange: (() -> Void)?

    private var token: NSObjectProtocol?

    public init() {}

    deinit {
        stop()
    }

    public func start() {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreensChange?()
        }
    }

    public func stop() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
