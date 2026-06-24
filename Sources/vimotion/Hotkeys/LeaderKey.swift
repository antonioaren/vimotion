import Carbon.HIToolbox

/// The modifier ("leader") that, combined with h/j/k/l, triggers navigation.
/// The direction keys are fixed (it wouldn't be Vim otherwise), but the leader
/// is configurable for people who'd rather not use Option.
public enum LeaderKey: String, CaseIterable, Sendable {
    case option
    case command
    case control
    case controlOption

    /// Carbon modifier mask used by `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        switch self {
        case .option: return UInt32(optionKey)
        case .command: return UInt32(cmdKey)
        case .control: return UInt32(controlKey)
        case .controlOption: return UInt32(controlKey) | UInt32(optionKey)
        }
    }

    /// Human-readable name for the menu.
    public var displayName: String {
        switch self {
        case .option: return "Option (⌥)"
        case .command: return "Command (⌘)"
        case .control: return "Control (⌃)"
        case .controlOption: return "Control + Option (⌃⌥)"
        }
    }

    /// Default leader key.
    public static let `default`: LeaderKey = .option
}
