import Foundation

/// What the updater should offer after looking at the published releases.
public enum UpdateDecision: Equatable {
    case upToDate
    /// A newer release on the current channel.
    case update(Release)
    /// The user is on a beta build but chose the Stable channel and no newer
    /// stable exists: offer the latest stable even though it is older.
    case switchToStable(Release)

    public var release: Release? {
        switch self {
        case .upToDate: return nil
        case .update(let release), .switchToStable(let release): return release
        }
    }
}

/// Pure release selection: no network, no UI, fully unit-tested.
public struct UpdateSelector {

    public init() {}

    /// - Parameter skipped: a version the user chose to skip; it is not offered
    ///   again, but a later one is.
    public func decide(current: AppVersion, channel: UpdateChannel, releases: [Release],
                       skipped: AppVersion? = nil) -> UpdateDecision {
        let candidates = channel == .stable ? releases.filter { !$0.isPrerelease } : releases
        guard let best = candidates.max(by: { $0.version < $1.version }),
              best.version != skipped else {
            return .upToDate
        }

        if best.version > current {
            return .update(best)
        }
        if channel == .stable, current.isPrerelease {
            return .switchToStable(best)
        }
        return .upToDate
    }
}
