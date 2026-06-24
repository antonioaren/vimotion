import Carbon.HIToolbox

/// Binding between a direction and the physical key that triggers it. The key
/// codes are the fixed Vim navigation keys h/j/k/l.
public struct Shortcut: Sendable {
    public let direction: Direction
    public let keyCode: UInt32

    /// The four fixed navigation shortcuts (h/j/k/l → left/down/up/right).
    public static let navigation: [Shortcut] = [
        Shortcut(direction: .left, keyCode: UInt32(kVK_ANSI_H)),
        Shortcut(direction: .down, keyCode: UInt32(kVK_ANSI_J)),
        Shortcut(direction: .up, keyCode: UInt32(kVK_ANSI_K)),
        Shortcut(direction: .right, keyCode: UInt32(kVK_ANSI_L)),
    ]
}
