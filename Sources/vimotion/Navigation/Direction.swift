import Foundation

/// A directional movement, mapped from Vim-style keys h/j/k/l.
///
/// Coordinate convention used across the navigation core: a **top-left origin**
/// where `y` grows downward (same as `CGWindowList`). So "up" means a smaller
/// `y`, "down" means a larger `y`.
public enum Direction: String, CaseIterable, Sendable {
    case left
    case down
    case up
    case right

    /// Maps a Vim navigation key (`h`, `j`, `k`, `l`) to a direction.
    public init?(key: Character) {
        switch key {
        case "h": self = .left
        case "j": self = .down
        case "k": self = .up
        case "l": self = .right
        default: return nil
        }
    }

    /// The Vim key associated with this direction.
    public var key: Character {
        switch self {
        case .left: return "h"
        case .down: return "j"
        case .up: return "k"
        case .right: return "l"
        }
    }

    /// Unit vector of the direction in the top-left coordinate convention.
    var vector: (dx: CGFloat, dy: CGFloat) {
        switch self {
        case .left: return (-1, 0)
        case .right: return (1, 0)
        case .up: return (0, -1)
        case .down: return (0, 1)
        }
    }

    /// Whether this direction moves along the horizontal axis.
    var isHorizontal: Bool {
        self == .left || self == .right
    }
}
