import XCTest
@testable import vimotion

final class UpdateControllerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var preferences: Preferences!
    private var fetcher: MockReleaseFetcher!
    private var installer: MockInstaller!
    private var prompter: MockPrompter!
    private var clock = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        let suite = "vimotion.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        preferences = Preferences(defaults: defaults)
        fetcher = MockReleaseFetcher()
        installer = MockInstaller()
        prompter = MockPrompter()
    }

    private func makeController(current: String? = "1.0.0") -> UpdateController {
        UpdateController(
            preferences: preferences,
            prompter: prompter,
            installer: installer,
            fetcher: fetcher,
            currentVersion: current.flatMap(AppVersion.init),
            now: { [unowned self] in self.clock }
        )
    }

    func testDefaults() {
        XCTAssertEqual(preferences.updateChannel, .stable)
        XCTAssertTrue(preferences.automaticallyChecksForUpdates)
        XCTAssertNil(preferences.lastUpdateCheck)
        XCTAssertNil(preferences.skippedVersion)
    }

    func testAvailableUpdateIsPromptedAndInstalled() {
        fetcher.result = .success([release("v1.1.0")])
        prompter.choice = .install
        let controller = makeController()

        controller.checkForUpdates(userInitiated: true)

        XCTAssertEqual(prompter.prompts, [.update(release("v1.1.0"))])
        XCTAssertEqual(installer.installed, [release("v1.1.0")])
        XCTAssertEqual(preferences.lastUpdateCheck, clock)
    }

    func testLaterKeepsUpdatePendingForTheMenu() {
        fetcher.result = .success([release("v1.1.0")])
        let controller = makeController()

        controller.checkForUpdates(userInitiated: false)

        XCTAssertEqual(controller.pendingUpdate?.release?.version, AppVersion("1.1.0"))
        XCTAssertTrue(installer.installed.isEmpty)

        prompter.choice = .install
        controller.installPendingUpdate()
        XCTAssertEqual(installer.installed, [release("v1.1.0")])
    }

    func testSkipIsRememberedForAutomaticChecksOnly() {
        fetcher.result = .success([release("v1.1.0")])
        prompter.choice = .skip
        let controller = makeController()

        controller.checkForUpdates(userInitiated: false)
        XCTAssertEqual(preferences.skippedVersion, AppVersion("1.1.0"))
        XCTAssertNil(controller.pendingUpdate)

        controller.checkForUpdates(userInitiated: false)
        XCTAssertEqual(prompter.prompts.count, 1)

        controller.checkForUpdates(userInitiated: true)
        XCTAssertEqual(prompter.prompts.count, 2)
    }

    func testManualCheckWhenUpToDateSaysSo() {
        fetcher.result = .success([release("v1.0.0")])
        let controller = makeController()

        controller.checkForUpdates(userInitiated: false)
        XCTAssertEqual(prompter.upToDateCount, 0)

        controller.checkForUpdates(userInitiated: true)
        XCTAssertEqual(prompter.upToDateCount, 1)
        XCTAssertTrue(prompter.prompts.isEmpty)
    }

    func testFetchErrorsAreOnlyShownForManualChecks() {
        fetcher.result = .failure(TestError())
        let controller = makeController()

        controller.checkForUpdates(userInitiated: false)
        XCTAssertTrue(prompter.errors.isEmpty)

        controller.checkForUpdates(userInitiated: true)
        XCTAssertEqual(prompter.errors.count, 1)
        XCTAssertNil(preferences.lastUpdateCheck)
    }

    func testInstallFailureIsReported() {
        fetcher.result = .success([release("v1.1.0")])
        installer.result = .failure(TestError())
        prompter.choice = .install
        let controller = makeController()

        controller.checkForUpdates(userInitiated: true)

        XCTAssertEqual(prompter.errors.count, 1)
        XCTAssertFalse(controller.isInstalling)
    }

    func testDevelopmentBuildNeverFetches() {
        let controller = makeController(current: nil)

        controller.checkForUpdates(userInitiated: false)
        controller.checkForUpdates(userInitiated: true)

        XCTAssertEqual(fetcher.fetchCount, 0)
        XCTAssertEqual(prompter.developmentBuildCount, 1)
    }

    func testCheckIfDueRespectsIntervalAndToggle() {
        let controller = makeController()

        controller.checkIfDue()
        XCTAssertEqual(fetcher.fetchCount, 1)

        clock += UpdateController.checkInterval - 1
        controller.checkIfDue()
        XCTAssertEqual(fetcher.fetchCount, 1)

        clock += 2
        controller.checkIfDue()
        XCTAssertEqual(fetcher.fetchCount, 2)

        clock += UpdateController.checkInterval
        controller.setAutomaticallyChecks(false)
        controller.checkIfDue()
        XCTAssertEqual(fetcher.fetchCount, 2)
    }

    func testJoiningBetaAsksForConfirmationThenChecks() {
        fetcher.result = .success([release("v1.0.0"), release("v1.1.0-beta.2")])
        let controller = makeController()

        prompter.joinBeta = false
        controller.setChannel(.beta)
        XCTAssertEqual(preferences.updateChannel, .stable)
        XCTAssertEqual(fetcher.fetchCount, 0)

        prompter.joinBeta = true
        controller.setChannel(.beta)
        XCTAssertEqual(preferences.updateChannel, .beta)
        XCTAssertEqual(prompter.prompts, [.update(release("v1.1.0-beta.2"))])
    }

    func testLeavingBetaOffersLatestStableEvenIfOlder() {
        preferences.updateChannel = .beta
        fetcher.result = .success([release("v1.0.0"), release("v1.1.0-beta.2")])
        prompter.choice = .install
        let controller = makeController(current: "1.1.0-beta.2")

        controller.setChannel(.stable)

        XCTAssertEqual(prompter.betaConfirmations, 0)
        XCTAssertEqual(prompter.prompts, [.switchToStable(release("v1.0.0"))])
        XCTAssertEqual(installer.installed, [release("v1.0.0")])
    }

    func testChangingChannelClearsSkippedVersion() {
        preferences.skippedVersion = AppVersion("1.1.0")
        let controller = makeController()

        controller.setChannel(.beta)

        XCTAssertNil(preferences.skippedVersion)
    }

    func testMenuVersionTitle() {
        XCTAssertEqual(MenuBarController.versionTitle(AppVersion("1.2.0")), "vimotion v1.2.0")
        XCTAssertEqual(MenuBarController.versionTitle(AppVersion("1.3.0-beta.4")), "vimotion v1.3.0-beta.4 (Beta)")
        XCTAssertEqual(MenuBarController.versionTitle(nil), "vimotion (development build)")
    }
}
