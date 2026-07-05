import SwiftUI

@main
struct FootballMenuBarApp: App {
    // Runs the AppDelegate so we can hide the Dock icon, own the match store
    // (alive for the whole lifetime so polling continues with the popover
    // closed), and drive the refresh loop.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MatchListView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.settingsWindow)
        } label: {
            // Rendered in its own view so it can observe the store and settings
            // and update the menu bar title as matches refresh.
            MenuBarLabel(store: appDelegate.store, settings: appDelegate.settings)
        }
        // `.window` hosts a richer scrollable SwiftUI popover (the match list)
        // instead of a flat native dropdown.
        .menuBarExtraStyle(.window)

        // Global configuration lives in a window we manage ourselves (see
        // `SettingsWindowManager`), opened from the popover footer, rather than
        // the stock `Settings` scene — that one opens behind other apps for an
        // accessory app and gives us no "is it open?" signal for the gear icon.
    }
}

/// The menu bar label. A pinned match turns it into a live text ticker; with no
/// pin (or the pinned match absent from the feed) it falls back to the ⚽
/// soccerball. While the pinned match is in-progress and the live indicator is
/// enabled, a red pill (mirroring the popover's live badge) is appended.
/// `@ObservedObject` on both the store and settings keeps it re-rendering as
/// either changes.
private struct MenuBarLabel: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var settings: AppSettings
    /// Included so the composited image re-renders when the menu bar switches
    /// between light and dark (its text is drawn with a fixed color).
    @Environment(\.colorScheme) private var colorScheme

    /// Menu-bar-sized crests for the pinned match, keyed by logo URL. Loaded in
    /// one task and composited into a single image (below): a `MenuBarExtra`
    /// label reliably renders only ONE image, so two separate crest views left
    /// the second blank. Drawing everything into one `NSImage` sidesteps that.
    @State private var crests: [URL: NSImage] = [:]

    private static let crestSize: CGFloat = 16

    var body: some View {
        content
            .task(id: crestTaskID) { await loadCrests() }
    }

    @ViewBuilder
    private var content: some View {
        if let match = store.pinnedSnapshot {
            if settings.showTeamLogos {
                // Single composited image: crests + score + live pill.
                Image(nsImage: composite(for: match))
            } else {
                HStack(spacing: 4) {
                    Text(MenuBarTitle.text(for: match,
                                           abbreviation: settings.effectiveAbbreviation(for:)) ?? "")
                    if match.isLive, settings.showLiveIndicator {
                        livePill(for: match)
                    }
                }
            }
        } else {
            Image(systemName: "soccerball")
        }
    }

    /// Task identity: reload the crests when the logo toggle flips or the pinned
    /// match's teams (hence their logo URLs) change.
    private var crestTaskID: String {
        guard settings.showTeamLogos, let m = store.pinnedSnapshot else { return "off" }
        return "\(m.home.logoURL?.absoluteString ?? "-")|\(m.away.logoURL?.absoluteString ?? "-")"
    }

    /// Load both teams' crests into `crests`, scaled for the menu bar, reusing
    /// the shared cache. Sequential awaits are fine — two small images.
    private func loadCrests() async {
        guard settings.showTeamLogos, let match = store.pinnedSnapshot else { return }
        for team in [match.home, match.away] {
            guard let url = team.logoURL, crests[url] == nil else { continue }
            var loaded = LogoCache.shared.cached(url)
            if loaded == nil { loaded = await LogoCache.shared.load(url) }
            if let loaded { crests[url] = Self.fitted(loaded, to: Self.crestSize) }
        }
    }

    /// The live indicator (text mode only). With the minute enabled it is a red
    /// capsule holding the match's status detail; otherwise a compact red dot.
    @ViewBuilder
    private func livePill(for match: Match) -> some View {
        if settings.includeMatchMinute {
            Text(match.statusDetail)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.red, in: Capsule())
        } else {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Logo-mode compositing

    /// Draw the whole logo-mode title — `[home] score [away] (pill)` — into one
    /// `NSImage`, the reliable way to get multiple crests plus text into a menu
    /// bar label. Non-template so the crests keep their colors; the text color
    /// tracks the current color scheme.
    private func composite(for match: Match) -> NSImage {
        let height: CGFloat = 18
        let gap: CGFloat = 3
        let textColor: NSColor = colorScheme == .dark ? .white : .black
        let scoreFont = NSFont.systemFont(ofSize: 13)
        let abbrFont = NSFont.systemFont(ofSize: 10, weight: .semibold)

        // Elements left→right: each is either a crest image or fallback text.
        func teamElement(_ team: Team) -> (image: NSImage?, text: NSAttributedString?, width: CGFloat) {
            if let url = team.logoURL, let img = crests[url] {
                return (img, nil, img.size.width)
            }
            let s = NSAttributedString(string: settings.effectiveAbbreviation(for: team).uppercased(),
                                       attributes: [.font: abbrFont, .foregroundColor: textColor])
            return (nil, s, s.size().width)
        }
        let home = teamElement(match.home)
        let away = teamElement(match.away)
        let score = NSAttributedString(string: MenuBarTitle.middle(for: match),
                                       attributes: [.font: scoreFont, .foregroundColor: textColor])
        let scoreSize = score.size()

        // Optional live pill.
        let showPill = match.isLive && settings.showLiveIndicator
        let pillText: NSAttributedString? = (showPill && settings.includeMatchMinute)
            ? NSAttributedString(string: match.statusDetail,
                                 attributes: [.font: abbrFont, .foregroundColor: NSColor.white])
            : nil
        let pillWidth: CGFloat = showPill ? (pillText.map { $0.size().width + 10 } ?? 7) : 0

        var width = home.width + gap + scoreSize.width + gap + away.width
        if showPill { width += gap + pillWidth }
        width = ceil(width) + 2

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        var x: CGFloat = 1

        func draw(_ el: (image: NSImage?, text: NSAttributedString?, width: CGFloat)) {
            if let img = el.image {
                img.draw(in: NSRect(x: x, y: (height - img.size.height) / 2,
                                    width: img.size.width, height: img.size.height),
                         from: NSRect(origin: .zero, size: img.size),
                         operation: .sourceOver, fraction: 1)
            } else if let t = el.text {
                t.draw(at: NSPoint(x: x, y: (height - t.size().height) / 2))
            }
            x += el.width
        }

        draw(home)
        x += gap
        score.draw(at: NSPoint(x: x, y: (height - scoreSize.height) / 2))
        x += scoreSize.width + gap
        draw(away)

        if showPill {
            x += gap
            if let pill = pillText {
                let pillHeight: CGFloat = 14
                let rect = NSRect(x: x, y: (height - pillHeight) / 2, width: pillWidth, height: pillHeight)
                NSColor.systemRed.setFill()
                NSBezierPath(roundedRect: rect, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()
                let ps = pill.size()
                pill.draw(at: NSPoint(x: x + (pillWidth - ps.width) / 2, y: (height - ps.height) / 2))
            } else {
                let dot: CGFloat = 7
                let rect = NSRect(x: x, y: (height - dot) / 2, width: dot, height: dot)
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// A copy of `image` scaled to fit within a `side`×`side` point box,
    /// preserving aspect ratio. Copying avoids mutating the shared cached image.
    private static func fitted(_ image: NSImage, to side: CGFloat) -> NSImage {
        let box = NSSize(width: side, height: side)
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let ratio = min(box.width / image.size.width, box.height / image.size.height)
        let drawn = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let out = NSImage(size: drawn)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: drawn),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// User configuration, alive for the app's lifetime and shared with the
    /// store (for cadence) and the views (for the live pill and overrides).
    let settings = AppSettings()

    /// Single source of truth for match data, live for the app's lifetime so
    /// polling continues even while the popover is closed.
    lazy var store = MatchStore(provider: ESPNProvider(), settings: settings)

    /// Owns the settings window (front-most while open) and publishes whether
    /// it's open so the popover's gear icon can reflect it.
    lazy var settingsWindow = SettingsWindowManager(settings: settings, store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `.accessory` keeps the app out of the Dock and the app switcher,
        // so it lives only in the menu bar.
        NSApp.setActivationPolicy(.accessory)

        // Reset the browsed day to today every time the popover opens. SwiftUI's
        // `.onAppear` fires only when the `.window`-style MenuBarExtra content is
        // first created (the window is reused across opens), so it can't do this.
        // The popover is this accessory app's only window, so its window becoming
        // key is a reliable "just opened" signal. `goToToday()` no-ops when
        // already on today, so repeat/spurious fires are harmless.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverWindowBecameKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil)

        store.start()
    }

    @objc private func popoverWindowBecameKey() {
        Task { await store.goToToday() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
