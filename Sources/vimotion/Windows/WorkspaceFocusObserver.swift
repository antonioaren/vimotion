import AppKit

/// Abstraction over global focus-change notifications, so the coordinator can
/// be tested with a mock instead of a live `NSWorkspace`.
public protocol FocusObserving: AnyObject {
    /// Called on the main thread whenever the frontmost application changes.
    var onFocusChange: (() -> Void)? { get set }

    /// Starts observing focus changes. Idempotent.
    func start()

    /// Stops observing focus changes.
    func stop()
}

/// Observes `NSWorkspace.didActivateApplicationNotification` to notice focus
/// changes made outside vimotion (mouse clicks, cmd-tab). App-level only:
/// same-app window switches via mouse are not reported by NSWorkspace.
public final class WorkspaceFocusObserver: FocusObserving {

    public var onFocusChange: (() -> Void)?

    private var token: NSObjectProtocol?

    public init() {}

    deinit {
        stop()
    }

    public func start() {
        guard token == nil else { return }
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onFocusChange?()
        }
    }

    public func stop() {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            self.token = nil
        }
    }
}
