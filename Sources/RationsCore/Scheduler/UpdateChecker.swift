import Foundation
import Observation

/// Opt-in: polls the latest GitHub release and remembers it if it is newer than
/// the running version. Follows the `Settings.checkForUpdates` default.
@MainActor
@Observable
final class UpdateChecker {
    struct Release: Equatable {
        let version: String
        let url: URL
    }

    private(set) var available: Release?
    private var loop: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    static let latestURL = URL(string: "https://api.github.com/repos/headconnect/rations/releases/latest")!
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    init() {
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync()
    }

    private func sync() {
        let enabled = UserDefaults.standard.bool(forKey: Settings.checkForUpdates)
        if enabled, loop == nil {
            loop = Task { [weak self] in await self?.run() }
        } else if !enabled, loop != nil {
            loop?.cancel()
            loop = nil
            available = nil
        }
    }

    private func run() async {
        while !Task.isCancelled {
            if let release = try? await Self.fetchLatest() {
                available = Self.isNewer(release.version, than: Self.currentVersion) ? release : nil
            }
            try? await Task.sleep(for: .seconds(6 * 3600))
        }
    }

    private static func fetchLatest() async throws -> Release {
        struct Response: Decodable {
            let tagName: String
            let htmlUrl: URL
        }
        let data = try await HTTP.get(latestURL, headers: [:])
        let response = try JSONDecoder.api.decode(Response.self, from: data)
        return Release(version: response.tagName.hasPrefix("v") ? String(response.tagName.dropFirst()) : response.tagName,
                       url: response.htmlUrl)
    }

    /// Numeric dotted versions; missing components count as 0, so 1.0 == 1.0.0.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
