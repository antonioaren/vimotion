import XCTest
@testable import vimotion

final class AppVersionTests: XCTestCase {

    private func v(_ string: String) -> AppVersion {
        guard let version = AppVersion(string) else {
            XCTFail("Could not parse \(string)")
            return AppVersion(major: 0, minor: 0, patch: 0)
        }
        return version
    }

    func testParsesStableVersion() {
        let version = v("1.2.3")

        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 2)
        XCTAssertEqual(version.patch, 3)
        XCTAssertFalse(version.isPrerelease)
        XCTAssertEqual(version.description, "1.2.3")
    }

    func testParsesTagWithLeadingVAndPrerelease() {
        let version = v("v1.2.0-beta.7")

        XCTAssertEqual(version.prerelease, ["beta", "7"])
        XCTAssertTrue(version.isPrerelease)
        XCTAssertEqual(version.description, "1.2.0-beta.7")
    }

    func testIgnoresBuildMetadata() {
        XCTAssertEqual(v("1.0.0+42"), v("1.0.0"))
    }

    func testRejectsMalformedVersions() {
        for bad in ["", "1", "1.2", "1.2.3.4", "a.b.c", "1.2.-3", "+1.2.3", "1.2.3-", "1.2.3-beta..1", "dev"] {
            XCTAssertNil(AppVersion(bad), "\(bad) should not parse")
        }
    }

    func testOrdersByCoreNumbersNumerically() {
        XCTAssertLessThan(v("1.2.3"), v("1.2.10"))
        XCTAssertLessThan(v("1.9.0"), v("1.10.0"))
        XCTAssertLessThan(v("1.99.99"), v("2.0.0"))
    }

    func testPrereleaseSortsBeforeItsRelease() {
        XCTAssertLessThan(v("1.2.0-beta.3"), v("1.2.0"))
        XCTAssertGreaterThan(v("1.2.0-beta.3"), v("1.1.9"))
    }

    func testPrereleaseNumbersCompareNumerically() {
        XCTAssertLessThan(v("1.2.0-beta.9"), v("1.2.0-beta.10"))
    }

    func testPrereleaseIdentifierRules() {
        XCTAssertLessThan(v("1.0.0-alpha"), v("1.0.0-alpha.1"))
        XCTAssertLessThan(v("1.0.0-alpha.1"), v("1.0.0-alpha.beta"))
        XCTAssertLessThan(v("1.0.0-alpha.beta"), v("1.0.0-beta"))
        XCTAssertLessThan(v("1.0.0-beta.11"), v("1.0.0-rc.1"))
    }
}
