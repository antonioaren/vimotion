import Foundation

/// Persists user choices (enabled state, leader key and update settings) in
/// `UserDefaults` so they survive restarts.
public final class Preferences {

    private enum Key {
        static let enabled = "vimotion.enabled"
        static let leader = "vimotion.leaderKey"
        static let updateChannel = "vimotion.updateChannel"
        static let autoCheckUpdates = "vimotion.automaticallyChecksForUpdates"
        static let lastUpdateCheck = "vimotion.lastUpdateCheck"
        static let skippedVersion = "vimotion.skippedVersion"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default to enabled on first launch.
        if defaults.object(forKey: Key.enabled) == nil {
            defaults.set(true, forKey: Key.enabled)
        }
        if defaults.object(forKey: Key.autoCheckUpdates) == nil {
            defaults.set(true, forKey: Key.autoCheckUpdates)
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

    // MARK: - Updates

    public var updateChannel: UpdateChannel {
        get {
            defaults.string(forKey: Key.updateChannel).flatMap(UpdateChannel.init(rawValue:)) ?? .default
        }
        set { defaults.set(newValue.rawValue, forKey: Key.updateChannel) }
    }

    public var automaticallyChecksForUpdates: Bool {
        get { defaults.bool(forKey: Key.autoCheckUpdates) }
        set { defaults.set(newValue, forKey: Key.autoCheckUpdates) }
    }

    public var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }

    /// A release the user chose to skip from an automatic prompt.
    public var skippedVersion: AppVersion? {
        get { defaults.string(forKey: Key.skippedVersion).flatMap(AppVersion.init) }
        set { defaults.set(newValue?.description, forKey: Key.skippedVersion) }
    }
}
