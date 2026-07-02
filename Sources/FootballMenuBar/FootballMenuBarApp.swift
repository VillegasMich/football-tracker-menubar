import SwiftUI

@main
struct FootballMenuBarApp: App {
    // Runs the AppDelegate so we can hide the Dock icon, own the match store,
    // and drive the refresh loop for the app's whole lifetime.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Football", systemImage: "soccerball") {
            MatchListView()
                .environmentObject(appDelegate.store)
        }
        // `.window` hosts a richer scrollable SwiftUI popover (the match list)
        // instead of a flat native dropdown.
        .menuBarExtraStyle(.window)
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
