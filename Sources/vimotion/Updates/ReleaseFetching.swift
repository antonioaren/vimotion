import Foundation

/// Source of published releases, so the updater can be tested without network.
public protocol ReleaseFetching {
    /// Calls back on the main queue.
    func fetchReleases(completion: @escaping (Result<[Release], Error>) -> Void)
}

/// Reads releases from the GitHub Releases API of the vimotion repository.
public final class GitHubReleaseClient: ReleaseFetching {

    public static let archiveName = "vimotion.zip"
    public static let checksumName = "vimotion.zip.sha256"

    public enum FetchError: LocalizedError {
        case badStatus(Int)

        public var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "GitHub answered with HTTP \(code)."
            }
        }
    }

    private let repository: String
    private let session: URLSession

    public init(repository: String = "antonioaren/vimotion", session: URLSession = .shared) {
        self.repository = repository
        self.session = session
    }

    public func fetchReleases(completion: @escaping (Result<[Release], Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=50") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("vimotion/\(AppVersion.current?.description ?? "dev")", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        session.dataTask(with: request) { data, response, error in
            let result: Result<[Release], Error>
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                result = .failure(FetchError.badStatus(http.statusCode))
            } else {
                result = Result { try Self.releases(from: data ?? Data()) }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// Parses the API payload, dropping drafts, non-SemVer tags and releases
    /// without the update archive and its checksum.
    static func releases(from data: Data) throws -> [Release] {
        try JSONDecoder().decode([Payload].self, from: data).compactMap { payload in
            guard !payload.draft,
                  let version = AppVersion(payload.tag_name),
                  let archive = payload.asset(named: archiveName),
                  let checksum = payload.asset(named: checksumName) else {
                return nil
            }
            return Release(
                version: version,
                tag: payload.tag_name,
                isPrerelease: payload.prerelease,
                archiveURL: archive,
                checksumURL: checksum,
                pageURL: payload.html_url.flatMap(URL.init(string:)),
                notes: payload.body ?? ""
            )
        }
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }

        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let body: String?
        let html_url: String?
        let assets: [Asset]

        func asset(named name: String) -> URL? {
            assets.first { $0.name == name }.flatMap { URL(string: $0.browser_download_url) }
        }
    }
}
