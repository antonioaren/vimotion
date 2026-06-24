/// Abstraction over global hotkey registration, so the coordinator depends on a
/// protocol rather than on Carbon directly. A future `CGEventTap`-based
/// implementation (e.g. for multi-key sequences) can drop in here unchanged.
public protocol HotkeyManaging: AnyObject {
    /// Called on the main thread when a navigation hotkey fires.
    var onDirection: ((Direction) -> Void)? { get set }

    /// Whether the hotkeys are currently registered/active.
    var isActive: Bool { get }

    /// Registers the navigation hotkeys using the given leader key. Re-registers
    /// if already active (e.g. after a leader change).
    func register(leader: LeaderKey)

    /// Unregisters all navigation hotkeys.
    func unregister()
}
