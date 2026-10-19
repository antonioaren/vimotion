import Foundation

/// A published vimotion release that the updater can install.
public struct Release: Equatable {
    public let version: AppVersion
    public let tag: String
    /// Marked as a GitHub pre-release, or carrying a SemVer pre-release suffix.
    public let isPrerelease: Bool
    public let archiveURL: URL
    public let checksumURL: URL
    public let pageURL: URL?
    /// Full release body (markdown).
    public let notes: String

    public init(version: AppVersion, tag: String, isPrerelease: Bool, archiveURL: URL,
                checksumURL: URL, pageURL: URL? = nil, notes: String = "") {
        self.version = version
        self.tag = tag
        self.isPrerelease = isPrerelease || version.isPrerelease
        self.archiveURL = archiveURL
        self.checksumURL = checksumURL
        self.pageURL = pageURL
        self.notes = notes
    }

    /// The "What's changed" section of the notes, without its heading — short
    /// enough for the update dialog. Falls back to the whole body.
    public var summary: String {
        let lines = notes.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## What") }) else {
            return notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex(where: { $0.hasPrefix("## ") }) ?? rest.endIndex
        return rest[..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
