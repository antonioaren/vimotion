import Foundation

/// Persists user choices (enabled state and leader key) in `UserDefaults` so
/// they survive restarts.
public final class Preferences {

    private enum Key {
        static let enabled = "vimotion.enabled"
        static let leader = "vimotion.leaderKey"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default to enabled on first launch.
        if defaults.object(forKey: Key.enabled) == nil {
            defaults.set(true, forKey: Key.enabled)
        }
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    public var leaderKey: LeaderKey {
        get {
            guard let raw = defaults.string(forKey: Key.leader),
                  let key = LeaderKey(rawValue: raw) else {
                return .default
            }
            return key
        }
        set { defaults.set(newValue.rawValue, forKey: Key.leader) }
    }
}
