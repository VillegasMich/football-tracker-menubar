import SwiftUI

/// In-memory cache of team logos keyed by URL. The menu bar popover is torn
/// down each time it closes, so a plain `AsyncImage` would re-fetch on every
/// open; caching the decoded `NSImage` loads each crest once per launch.
@MainActor
final class LogoCache: ObservableObject {
    static let shared = LogoCache()

    private var images: [URL: NSImage] = [:]
    /// URLs currently being fetched, to avoid duplicate concurrent requests.
    private var inFlight: Set<URL> = []

    func cached(_ url: URL) -> NSImage? { images[url] }

    /// Fetch and cache the logo at `url` if not already present. Failures are
    /// swallowed — the view falls back to the abbreviation.
    func load(_ url: URL) async -> NSImage? {
        if let image = images[url] { return image }
        guard !inFlight.contains(url) else { return nil }
        inFlight.insert(url)
        defer { inFlight.remove(url) }
        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let image = NSImage(data: data)
        else { return nil }
        images[url] = image
        return image
    }
}

/// A team's crest at row size, falling back to the uppercased abbreviation when
/// there is no logo URL or the image fails to load.
struct TeamLogoView: View {
    let team: Team
    var size: CGFloat = 18

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
        Text(team.abbreviation.uppercased())
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
