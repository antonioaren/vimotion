import Foundation

/// A SemVer 2.0 version such as `1.2.0` or `1.2.0-beta.3`. A leading `v` is
/// accepted and build metadata (`+…`) is ignored. Ordering follows SemVer, so
/// `1.2.0-beta.9 < 1.2.0-beta.10 < 1.2.0`.
public struct AppVersion: Comparable, Hashable, CustomStringConvertible {

    public let major: Int
    public let minor: Int
    public let patch: Int
    /// Dot-separated pre-release identifiers (`["beta", "3"]`); empty for stable.
    public let prerelease: [String]

    public init(major: Int, minor: Int, patch: Int, prerelease: [String] = []) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public init?(_ string: String) {
        var text = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        if let plus = text.firstIndex(of: "+") { text = text[..<plus] }

        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3, core.allSatisfy(Self.isNumeric),
              let major = Int(core[0]), let minor = Int(core[1]), let patch = Int(core[2]) else {
            return nil
        }

        var prerelease: [String] = []
        if parts.count == 2 {
            prerelease = parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard prerelease.allSatisfy({ !$0.isEmpty }) else { return nil }
        }
        self.init(major: major, minor: minor, patch: patch, prerelease: prerelease)
    }

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // A pre-release sorts before the release it precedes.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true), (true, false): return false
        case (false, true): return true
        case (false, false): break
        }

        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            switch (numericValue(a), numericValue(b)) {
            case let (x?, y?): return x < y
            case (_?, nil): return true // numeric identifiers sort before alphanumeric ones
            case (nil, _?): return false
            case (nil, nil): return a < b
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func isNumeric<S: StringProtocol>(_ text: S) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func numericValue(_ identifier: String) -> Int? {
        isNumeric(identifier) ? Int(identifier) : nil
    }
}

extension AppVersion {
    /// The version of the running app bundle, or `nil` for development builds
    /// (`swift run`) that have no `Info.plist`.
    public static var current: AppVersion? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }
        return AppVersion(string)
    }
}
