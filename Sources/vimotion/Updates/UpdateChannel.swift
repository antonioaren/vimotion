import Foundation

/// Which releases the updater offers: only stable ones, or betas too.
public enum UpdateChannel: String, CaseIterable {
    case stable
    case beta

    public static let `default`: UpdateChannel = .stable

    public var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }
}
