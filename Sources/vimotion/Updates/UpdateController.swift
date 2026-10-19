import Foundation

public enum UpdatePromptChoice {
    case install
    case later
    case skip
}

/// The dialogs the updater needs, kept behind a protocol so the flow can be
/// tested without AppKit.
public protocol UpdatePrompting: AnyObject {
    func promptForUpdate(_ decision: UpdateDecision, current: AppVersion) -> UpdatePromptChoice
    func confirmJoinBeta() -> Bool
    func showUpToDate(current: AppVersion, channel: UpdateChannel)
    func showDevelopmentBuild()
    func showError(_ error: Error, releasePage: URL?)
}

public protocol UpdateInstalling {
    /// Calls back on the main queue. On success the app quits and relaunches.
    func install(_ release: Release, completion: @escaping (Result<Void, Error>) -> Void)
}

/// Orchestrates update checks: on launch, every 24 hours (while automatic
/// checks are on), on demand from the menu and whenever the channel changes.
public final class UpdateController {

    public static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let pollInterval: TimeInterval = 60 * 60

    private let preferences: Preferences
    private let fetcher: ReleaseFetching
    private let installer: UpdateInstalling
    private let selector: UpdateSelector
    private let prompter: UpdatePrompting
    private let now: () -> Date
    private var timer: Timer?

    /// `nil` for development builds, which never update themselves.
    public let currentVersion: AppVersion?
    /// The last non-trivial decision, surfaced in the menu as "Update to…".
    public private(set) var pendingUpdate: UpdateDecision?
    public private(set) var isChecking = false
    public private(set) var isInstalling = false

    public var onStateChange: (() -> Void)?

    public init(
        preferences: Preferences,
        prompter: UpdatePrompting,
        installer: UpdateInstalling,
        fetcher: ReleaseFetching = GitHubReleaseClient(),
        selector: UpdateSelector = UpdateSelector(),
        currentVersion: AppVersion? = AppVersion.current,
        now: @escaping () -> Date = Date.init
    ) {
        self.preferences = preferences
        self.prompter = prompter
        self.installer = installer
        self.fetcher = fetcher
        self.selector = selector
        self.currentVersion = currentVersion
        self.now = now
    }

    public var channel: UpdateChannel { preferences.updateChannel }
    public var automaticallyChecks: Bool { preferences.automaticallyChecksForUpdates }

    public func start() {
        // Poll hourly and let `checkIfDue` decide, so checks still happen
        // roughly daily after the Mac wakes from sleep.
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
        checkIfDue()
    }

    public func checkIfDue() {
        guard preferences.automaticallyChecksForUpdates else { return }
        if let last = preferences.lastUpdateCheck, now().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        checkForUpdates(userInitiated: false)
    }

    public func checkForUpdates(userInitiated: Bool) {
        guard !isChecking, !isInstalling else { return }
        guard let current = currentVersion else {
            if userInitiated { prompter.showDevelopmentBuild() }
            return
        }

        isChecking = true
        onStateChange?()
        fetcher.fetchReleases { [weak self] result in
            guard let self else { return }
            self.isChecking = false
            switch result {
            case .failure(let error):
                Log.error("Update check failed: \(error.localizedDescription)")
                self.onStateChange?()
                if userInitiated { self.prompter.showError(error, releasePage: nil) }

            case .success(let releases):
                self.preferences.lastUpdateCheck = self.now()
                let decision = self.selector.decide(
                    current: current,
                    channel: self.preferences.updateChannel,
                    releases: releases,
                    skipped: userInitiated ? nil : self.preferences.skippedVersion
                )
                self.pendingUpdate = decision.release == nil ? nil : decision
                self.onStateChange?()

                if decision.release != nil {
                    self.prompt(decision, current: current)
                } else if userInitiated {
                    self.prompter.showUpToDate(current: current, channel: self.preferences.updateChannel)
                }
            }
        }
    }

    /// Re-opens the prompt for the update shown in the menu.
    public func installPendingUpdate() {
        guard let pendingUpdate, let current = currentVersion, !isInstalling else { return }
        prompt(pendingUpdate, current: current)
    }

    public func setChannel(_ channel: UpdateChannel) {
        guard channel != preferences.updateChannel else { return }
        if channel == .beta, !prompter.confirmJoinBeta() { return }
        preferences.updateChannel = channel
        preferences.skippedVersion = nil
        pendingUpdate = nil
        onStateChange?()
        checkForUpdates(userInitiated: true)
    }

    public func setAutomaticallyChecks(_ enabled: Bool) {
        preferences.automaticallyChecksForUpdates = enabled
        onStateChange?()
        if enabled { checkIfDue() }
    }

    // MARK: - Private

    private func prompt(_ decision: UpdateDecision, current: AppVersion) {
        guard let release = decision.release else { return }
        switch prompter.promptForUpdate(decision, current: current) {
        case .install:
            install(release)
        case .later:
            break
        case .skip:
            preferences.skippedVersion = release.version
            pendingUpdate = nil
            onStateChange?()
        }
    }

    private func install(_ release: Release) {
        isInstalling = true
        onStateChange?()
        Log.info("Installing vimotion \(release.version)")
        installer.install(release) { [weak self] result in
            guard let self else { return }
            self.isInstalling = false
            self.onStateChange?()
            if case .failure(let error) = result {
                Log.error("Update install failed: \(error.localizedDescription)")
                self.prompter.showError(error, releasePage: release.pageURL)
            }
        }
    }
}
