import AppKit
import CryptoKit

/// Downloads a release, verifies its SHA-256, swaps the running `.app` bundle
/// for the new one and relaunches.
///
/// The swap runs in a detached shell script that waits for this process to
/// exit: a running bundle can't safely replace itself in place.
public final class UpdateInstaller: UpdateInstalling {

    public enum InstallError: LocalizedError {
        case notInAppBundle
        case notWritable(URL)
        case download(Error)
        case badChecksumFile
        case checksumMismatch
        case extractionFailed
        case invalidBundle
        case launchFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .notInAppBundle:
                return "vimotion isn't running from an app bundle, so it can't replace itself."
            case .notWritable(let url):
                return "vimotion can't write to \(url.path). Move vimotion.app to /Applications or download the update manually."
            case .download(let error):
                return "The download failed: \(error.localizedDescription)"
            case .badChecksumFile:
                return "The release's checksum file is malformed."
            case .checksumMismatch:
                return "The downloaded update doesn't match its checksum and was discarded."
            case .extractionFailed:
                return "The downloaded update couldn't be unpacked."
            case .invalidBundle:
                return "The downloaded update isn't a valid vimotion app."
            case .launchFailed(let error):
                return "The installer couldn't start: \(error.localizedDescription)"
            }
        }
    }

    private let bundle: Bundle
    private let session: URLSession
    private let fileManager = FileManager.default
    private let workQueue = DispatchQueue(label: "com.antonioaren.vimotion.updater")

    public init(bundle: Bundle = .main, session: URLSession = .shared) {
        self.bundle = bundle
        self.session = session
    }

    public func install(_ release: Release, completion: @escaping (Result<Void, Error>) -> Void) {
        let fail: (InstallError) -> Void = { error in
            DispatchQueue.main.async { completion(.failure(error)) }
        }

        let appURL = bundle.bundleURL
        guard appURL.pathExtension == "app" else { return fail(.notInAppBundle) }
        let parentURL = appURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentURL.path),
              fileManager.isWritableFile(atPath: appURL.path) else {
            return fail(.notWritable(parentURL))
        }

        let workDir = fileManager.temporaryDirectory
            .appendingPathComponent("vimotion-update-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            return fail(.download(error))
        }
        let checksumURL = workDir.appendingPathComponent(GitHubReleaseClient.checksumName)
        let archiveURL = workDir.appendingPathComponent(GitHubReleaseClient.archiveName)

        download(release.checksumURL, to: checksumURL) { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result { return fail(.download(error)) }

            self.download(release.archiveURL, to: archiveURL) { result in
                if case .failure(let error) = result { return fail(.download(error)) }

                self.workQueue.async {
                    do {
                        try self.verify(archiveURL, against: checksumURL)
                        let newAppURL = try self.extract(archiveURL, into: workDir)
                        DispatchQueue.main.async {
                            do {
                                try self.launchReplacement(old: appURL, new: newAppURL, workDir: workDir)
                            } catch {
                                return completion(.failure(InstallError.launchFailed(error)))
                            }
                            completion(.success(()))
                            NSApp.terminate(nil)
                        }
                    } catch let error as InstallError {
                        try? self.fileManager.removeItem(at: workDir)
                        fail(error)
                    } catch {
                        try? self.fileManager.removeItem(at: workDir)
                        fail(.extractionFailed)
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private func download(_ source: URL, to destination: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        session.downloadTask(with: source) { [fileManager] location, response, error in
            if let error { return completion(.failure(error)) }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return completion(.failure(GitHubReleaseClient.FetchError.badStatus(http.statusCode)))
            }
            guard let location else { return completion(.failure(URLError(.badServerResponse))) }
            // The temporary file is deleted when this handler returns.
            completion(Result { try fileManager.moveItem(at: location, to: destination) })
        }.resume()
    }

    private func verify(_ archive: URL, against checksumFile: URL) throws {
        guard let text = try? String(contentsOf: checksumFile, encoding: .utf8),
              let expected = text.split(whereSeparator: \.isWhitespace).first?.lowercased(),
              expected.count == 64 else {
            throw InstallError.badChecksumFile
        }
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw InstallError.checksumMismatch }
    }

    private func extract(_ archive: URL, into workDir: URL) throws -> URL {
        let extractDir = workDir.appendingPathComponent("extracted", isDirectory: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, extractDir.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw InstallError.extractionFailed }

        let contents = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        guard let newApp = contents.first(where: { $0.pathExtension == "app" }),
              let newBundle = Bundle(url: newApp),
              newBundle.bundleIdentifier == bundle.bundleIdentifier,
              let executable = newBundle.executableURL,
              fileManager.isExecutableFile(atPath: executable.path) else {
            throw InstallError.invalidBundle
        }
        return newApp
    }

    private func launchReplacement(old: URL, new: URL, workDir: URL) throws {
        let script = workDir.appendingPathComponent("install.sh")
        try Self.replacementScript.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            script.path,
            String(ProcessInfo.processInfo.processIdentifier),
            old.path,
            new.path,
            workDir.path,
        ]
        try process.run()
    }

    /// Args: <pid> <installed .app> <new .app> <work dir>. Keeps the old bundle
    /// until the new one is in place and restores it if the move fails.
    private static let replacementScript = """
    #!/bin/sh
    PID="$1"; OLD="$2"; NEW="$3"; WORK="$4"
    while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
    BACKUP="$WORK/previous.app"
    if mv "$OLD" "$BACKUP"; then
        if mv "$NEW" "$OLD"; then
            rm -rf "$BACKUP"
        else
            mv "$BACKUP" "$OLD"
        fi
    fi
    xattr -dr com.apple.quarantine "$OLD" 2>/dev/null
    open "$OLD"
    rm -rf "$WORK"
    """
}
