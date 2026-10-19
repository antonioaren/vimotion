import XCTest
@testable import vimotion

final class UpdateSelectorTests: XCTestCase {

    private let selector = UpdateSelector()
    private let releases = [
        makeRelease("v1.0.0"),
        makeRelease("v1.1.0"),
        makeRelease("v1.2.0-beta.3"),
        makeRelease("v1.2.0-beta.10"),
    ]

    private func decide(_ current: String, _ channel: UpdateChannel, releases: [Release]? = nil,
                        skipped: String? = nil) -> UpdateDecision {
        selector.decide(current: AppVersion(current)!, channel: channel,
                        releases: releases ?? self.releases, skipped: skipped.flatMap(AppVersion.init))
    }

    func testStableToNewerStable() {
        XCTAssertEqual(decide("1.0.0", .stable), .update(makeRelease("v1.1.0")))
    }

    func testStableChannelIgnoresBetas() {
        XCTAssertEqual(decide("1.1.0", .stable), .upToDate)
    }

    func testBetaChannelOffersNewestBeta() {
        XCTAssertEqual(decide("1.1.0", .beta), .update(makeRelease("v1.2.0-beta.10")))
        XCTAssertEqual(decide("1.2.0-beta.3", .beta), .update(makeRelease("v1.2.0-beta.10")))
    }

    func testBetaChannelOffersStableThatSupersedesBeta() {
        let withStable = releases + [makeRelease("v1.2.0")]

        XCTAssertEqual(decide("1.2.0-beta.10", .beta, releases: withStable), .update(makeRelease("v1.2.0")))
    }

    func testBetaUserSwitchingToStableGetsNewerStable() {
        let withStable = releases + [makeRelease("v1.2.0")]

        XCTAssertEqual(decide("1.2.0-beta.10", .stable, releases: withStable), .update(makeRelease("v1.2.0")))
    }

    func testBetaUserSwitchingToStableDowngradesToLatestStable() {
        XCTAssertEqual(decide("1.2.0-beta.10", .stable), .switchToStable(makeRelease("v1.1.0")))
    }

    func testUpToDateOnBetaChannel() {
        XCTAssertEqual(decide("1.2.0-beta.10", .beta), .upToDate)
    }

    func testNoReleases() {
        XCTAssertEqual(decide("1.0.0", .stable, releases: []), .upToDate)
        XCTAssertEqual(decide("1.0.0-beta.1", .stable, releases: []), .upToDate)
    }

    func testSkippedVersionIsNotOfferedButLaterOneIs() {
        XCTAssertEqual(decide("1.0.0", .stable, skipped: "1.1.0"), .upToDate)

        let withNewer = releases + [makeRelease("v1.3.0")]
        XCTAssertEqual(decide("1.0.0", .stable, releases: withNewer, skipped: "1.1.0"), .update(makeRelease("v1.3.0")))
    }

    func testGitHubPrereleaseFlagKeepsReleaseOffStableChannel() {
        let flagged = [makeRelease("v1.0.0"), makeRelease("v2.0.0", prerelease: true)]

        XCTAssertEqual(decide("1.0.0", .stable, releases: flagged), .upToDate)
        XCTAssertEqual(decide("1.0.0", .beta, releases: flagged), .update(makeRelease("v2.0.0", prerelease: true)))
    }
}
