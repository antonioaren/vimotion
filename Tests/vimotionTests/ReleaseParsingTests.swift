import XCTest
@testable import vimotion

final class ReleaseParsingTests: XCTestCase {

    private func asset(_ tag: String, _ name: String) -> String {
        """
        {"name": "\(name)", "browser_download_url": "https://github.com/antonioaren/vimotion/releases/download/\(tag)/\(name)"}
        """
    }

    private func payload(_ tag: String, draft: Bool = false, prerelease: Bool = false,
                         assets: [String] = ["vimotion.zip", "vimotion.zip.sha256"], body: String = "notes") -> String {
        """
        {
          "tag_name": "\(tag)",
          "draft": \(draft),
          "prerelease": \(prerelease),
          "body": "\(body)",
          "html_url": "https://github.com/antonioaren/vimotion/releases/tag/\(tag)",
          "assets": [\(assets.map { asset(tag, $0) }.joined(separator: ","))]
        }
        """
    }

    func testParsesUsableReleasesAndSkipsTheRest() throws {
        let json = "[" + [
            payload("v1.1.0"),
            payload("v1.2.0-beta.4", prerelease: true),
            payload("v9.9.9", draft: true),
            payload("nightly"),
            payload("v1.0.5", assets: ["vimotion.zip"]),
        ].joined(separator: ",") + "]"

        let releases = try GitHubReleaseClient.releases(from: Data(json.utf8))

        XCTAssertEqual(releases.map(\.tag), ["v1.1.0", "v1.2.0-beta.4"])
        XCTAssertFalse(releases[0].isPrerelease)
        XCTAssertTrue(releases[1].isPrerelease)
        XCTAssertEqual(releases[0].archiveURL.lastPathComponent, "vimotion.zip")
        XCTAssertEqual(releases[0].checksumURL.lastPathComponent, "vimotion.zip.sha256")
        XCTAssertEqual(releases[0].notes, "notes")
    }

    func testSemverPrereleaseTagIsPrereleaseEvenWithoutGitHubFlag() throws {
        let json = "[" + payload("v1.2.0-beta.1", prerelease: false) + "]"

        let releases = try GitHubReleaseClient.releases(from: Data(json.utf8))

        XCTAssertTrue(releases[0].isPrerelease)
    }

    func testSummaryExtractsWhatsChangedSection() {
        let notes = """
        ## What's changed

        ### New
        - You can now update from the menu bar.

        ## Commits

        - feat: updater (abc123) — antonioaren
        """

        XCTAssertEqual(makeRelease("v1.1.0", notes: notes).summary, "### New\n- You can now update from the menu bar.")
    }

    func testSummaryFallsBackToWholeBody() {
        XCTAssertEqual(makeRelease("v1.1.0", notes: "  Just a note.\n").summary, "Just a note.")
    }
}
