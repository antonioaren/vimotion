import Foundation
@testable import vimotion

func makeRelease(_ tag: String, prerelease: Bool? = nil, notes: String = "") -> Release {
    let version = AppVersion(tag)!
    let base = URL(string: "https://example.com/\(tag)/")!
    return Release(
        version: version,
        tag: tag,
        isPrerelease: prerelease ?? version.isPrerelease,
        archiveURL: base.appendingPathComponent("vimotion.zip"),
        checksumURL: base.appendingPathComponent("vimotion.zip.sha256"),
        pageURL: base,
        notes: notes
    )
}

final class MockReleaseFetcher: ReleaseFetching {
    var result: Result<[Release], Error> = .success([])
    private(set) var fetchCount = 0

    func fetchReleases(completion: @escaping (Result<[Release], Error>) -> Void) {
        fetchCount += 1
        completion(result)
    }
}

final class MockInstaller: UpdateInstalling {
    var result: Result<Void, Error> = .success(())
    private(set) var installed: [Release] = []

    func install(_ release: Release, completion: @escaping (Result<Void, Error>) -> Void) {
        installed.append(release)
        completion(result)
    }
}

final class MockPrompter: UpdatePrompting {
    var choice: UpdatePromptChoice = .later
    var joinBeta = true
    private(set) var prompts: [UpdateDecision] = []
    private(set) var upToDateCount = 0
    private(set) var developmentBuildCount = 0
    private(set) var errors: [Error] = []
    private(set) var betaConfirmations = 0

    func promptForUpdate(_ decision: UpdateDecision, current: AppVersion) -> UpdatePromptChoice {
        prompts.append(decision)
        return choice
    }

    func confirmJoinBeta() -> Bool {
        betaConfirmations += 1
        return joinBeta
    }

    func showUpToDate(current: AppVersion, channel: UpdateChannel) { upToDateCount += 1 }
    func showDevelopmentBuild() { developmentBuildCount += 1 }
    func showError(_ error: Error, releasePage: URL?) { errors.append(error) }
}

struct TestError: Error {}
