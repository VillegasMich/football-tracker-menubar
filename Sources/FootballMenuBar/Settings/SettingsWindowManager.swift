import AppKit
import SwiftUI

/// Owns the settings window for this accessory (Dock-less) app.
///
/// The stock SwiftUI `Settings` scene opened via `SettingsLink` has two problems
/// here: it tends to open *behind* other apps (an `.accessory` app doesn't
/// activate the way a regular app does), and it exposes no signal for whether
/// it's on screen — so the menu bar gear can't reflect its state. Hosting the
/// same `SettingsView` in an AppKit window we manage fixes both: we activate and
/// float it to the front on open, and publish `isOpen` for the gear to observe.
@MainActor
final class SettingsWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    /// Whether the settings window is currently on screen. Drives the gear icon
    /// in the popover footer (outline → filled) and its roll animation.
    @Published private(set) var isOpen = false

    private var window: NSWindow?
    private let settings: AppSettings
    private let store: MatchStore

    init(settings: AppSettings, store: MatchStore) {
        self.settings = settings
        self.store = store
    }

    /// Opens the window if closed, or brings it forward if already open.
    func toggle() {
        if isOpen { close() } else { open() }
    }

    func open() {
        // Pull the whole app forward so the window lands on top of whatever the
        // user was in, instead of opening buried behind it.
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            bringToFront(window)
            return
        }

        let root = SettingsView()
            .environmentObject(settings)
            .environmentObject(store)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Football Settings"
        window.styleMask = [.titled, .closable]
        // Reuse the window across opens (and let us track close via the delegate)
        // rather than having AppKit deallocate it on close.
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Keep it above other apps' windows while it's open — this is the
        // "priority over other windows" the app otherwise lacks as an accessory.
        // Drop this to `.normal` if a settings window that floats everywhere
        // feels too aggressive.
        window.level = .floating
        window.center()
        self.window = window
        bringToFront(window)
    }

    func close() {
        window?.close()
    }

    private func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        // `orderFrontRegardless` surfaces the window even when the accessory app
        // isn't the active app, covering cases where activation alone doesn't
        // pull it forward.
        window.orderFrontRegardless()
        isOpen = true
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        isOpen = false
    }
}
