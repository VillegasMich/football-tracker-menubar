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
        } label: {
            // Rendered in its own view so it can observe the store and update
            // the menu bar title as matches refresh.
            MenuBarLabel(store: appDelegate.store)
        }
        // `.window` hosts a richer scrollable SwiftUI popover (the match list)
        // instead of a flat native dropdown.
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar label. A pinned match turns it into a live text ticker; with no
/// pin (or the pinned match absent from the feed) it falls back to the ⚽
/// soccerball. `@ObservedObject` keeps it re-rendering as the store refreshes.
private struct MenuBarLabel: View {
    @ObservedObject var store: MatchStore

    var body: some View {
        if let title = MenuBarTitle.text(for: store.pinnedSnapshot) {
            Text(title)
        } else {
            Image(systemName: "soccerball")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Single source of truth for match data, live for the app's lifetime so
    /// polling continues even while the popover is closed.
    let store = MatchStore(provider: ESPNProvider())

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `.accessory` keeps the app out of the Dock and the app switcher,
        // so it lives only in the menu bar.
        NSApp.setActivationPolicy(.accessory)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
