import Carbon.HIToolbox

/// What a hotkey does when it fires: move focus in a direction or toggle back
/// to the last visited window.
public enum HotkeyAction: Sendable {
    case navigate(Direction)
    case toggleLastWindow
}

/// Binding between an action and the physical key that triggers it. The key
/// codes are fixed: the Vim navigation keys h/j/k/l plus n for the toggle.
public struct Shortcut: Sendable {
    public let action: HotkeyAction
    public let keyCode: UInt32

    /// All fixed shortcuts (h/j/k/l → left/down/up/right, n → toggle).
    public static let all: [Shortcut] = [
        Shortcut(action: .navigate(.left), keyCode: UInt32(kVK_ANSI_H)),
        Shortcut(action: .navigate(.down), keyCode: UInt32(kVK_ANSI_J)),
        Shortcut(action: .navigate(.up), keyCode: UInt32(kVK_ANSI_K)),
        Shortcut(action: .navigate(.right), keyCode: UInt32(kVK_ANSI_L)),
        Shortcut(action: .toggleLastWindow, keyCode: UInt32(kVK_ANSI_N)),
    ]
}
