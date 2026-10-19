import XCTest
@testable import vimotion

final class UpdateSelectorTests: XCTestCase {

    private let selector = UpdateSelector()
    private let releases = [
        release("v1.0.0"),
        release("v1.1.0"),
        release("v1.2.0-beta.3"),
        release("v1.2.0-beta.10"),
    ]

    private func decide(_ current: String, _ channel: UpdateChannel, releases: [Release]? = nil,
                        skipped: String? = nil) -> UpdateDecision {
        selector.decide(current: AppVersion(current)!, channel: channel,
                        releases: releases ?? self.releases, skipped: skipped.flatMap(AppVersion.init))
    }

    func testStableToNewerStable() {
        XCTAssertEqual(decide("1.0.0", .stable), .update(release("v1.1.0")))
    }

    func testStableChannelIgnoresBetas() {
        XCTAssertEqual(decide("1.1.0", .stable), .upToDate)
    }

    func testBetaChannelOffersNewestBeta() {
        XCTAssertEqual(decide("1.1.0", .beta), .update(release("v1.2.0-beta.10")))
        XCTAssertEqual(decide("1.2.0-beta.3", .beta), .update(release("v1.2.0-beta.10")))
    }

    func testBetaChannelOffersStableThatSupersedesBeta() {
        let withStable = releases + [release("v1.2.0")]

        XCTAssertEqual(decide("1.2.0-beta.10", .beta, releases: withStable), .update(release("v1.2.0")))
    }

    func testBetaUserSwitchingToStableGetsNewerStable() {
        let withStable = releases + [release("v1.2.0")]

        XCTAssertEqual(decide("1.2.0-beta.10", .stable, releases: withStable), .update(release("v1.2.0")))
    }

    func testBetaUserSwitchingToStableDowngradesToLatestStable() {
        XCTAssertEqual(decide("1.2.0-beta.10", .stable), .switchToStable(release("v1.1.0")))
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

        let withNewer = releases + [release("v1.3.0")]
        XCTAssertEqual(decide("1.0.0", .stable, releases: withNewer, skipped: "1.1.0"), .update(release("v1.3.0")))
    }

    func testGitHubPrereleaseFlagKeepsReleaseOffStableChannel() {
        let flagged = [release("v1.0.0"), release("v2.0.0", prerelease: true)]

        XCTAssertEqual(decide("1.0.0", .stable, releases: flagged), .upToDate)
        XCTAssertEqual(decide("1.0.0", .beta, releases: flagged), .update(release("v2.0.0", prerelease: true)))
    }
}
