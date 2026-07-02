import SwiftUI

@main
struct FootballMenuBarApp: App {
    // Runs the AppDelegate so we can hide the Dock icon and make this a
    // pure menu bar ("accessory") app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Football", systemImage: "soccerball") {
            MenuContent()
        }
        // `.menu` is a native dropdown; switch to `.window` for a popover
        // that can host a richer SwiftUI view.
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `.accessory` keeps the app out of the Dock and the app switcher,
        // so it lives only in the menu bar.
        NSApp.setActivationPolicy(.accessory)
    }
}
