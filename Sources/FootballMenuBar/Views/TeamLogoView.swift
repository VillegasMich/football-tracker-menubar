import SwiftUI

/// In-memory cache of team logos keyed by URL. The menu bar popover is torn
/// down each time it closes, so a plain `AsyncImage` would re-fetch on every
/// open; caching the decoded `NSImage` loads each crest once per launch.
@MainActor
final class LogoCache: ObservableObject {
    static let shared = LogoCache()

    private var images: [URL: NSImage] = [:]
    /// In-flight downloads keyed by URL. Concurrent callers for the same URL
    /// await the same task rather than starting a duplicate — or, as before,
    /// being turned away with `nil` (which left a second view, e.g. the menu bar
    /// crest racing the still-alive popover, permanently blank). The task yields
    /// `Data` (which is `Sendable` on the macOS 13 floor); the `NSImage` is built
    /// here on the main actor.
    private var tasks: [URL: Task<Data?, Never>] = [:]

    func cached(_ url: URL) -> NSImage? { images[url] }

    /// Fetch and cache the logo at `url` if not already present, coalescing
    /// concurrent requests for the same URL. Failures are swallowed — the view
    /// falls back to the abbreviation.
    func load(_ url: URL) async -> NSImage? {
        if let image = images[url] { return image }

        let task: Task<Data?, Never>
        if let existing = tasks[url] {
            task = existing
        } else {
            task = Task { try? await URLSession.shared.data(from: url).0 }
            tasks[url] = task
        }
        let data = await task.value
        tasks[url] = nil
        guard let data, let image = NSImage(data: data) else { return nil }
        images[url] = image
        return image
    }
}

/// A team's crest at row size, falling back to the uppercased abbreviation when
/// there is no logo URL or the image fails to load.
struct TeamLogoView: View {
    let team: Team
    var size: CGFloat = 18

    @EnvironmentObject private var settings: AppSettings
    @StateObject private var cache = LogoCache.shared
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .task(id: team.logoURL) { await loadLogo() }
    }

    private var fallback: some View {
        Text(settings.effectiveAbbreviation(for: team).uppercased())
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.secondary)
    }

    private func loadLogo() async {
        guard let url = team.logoURL else {
            image = nil
            return
        }
        if let cached = cache.cached(url) {
            image = cached
            return
        }
        image = await cache.load(url)
    }
}
