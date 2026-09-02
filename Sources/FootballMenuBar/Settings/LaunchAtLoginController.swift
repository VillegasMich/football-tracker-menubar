import Foundation
import ServiceManagement

/// Owns the app's "open at login" registration.
///
/// Unlike every setting in `AppSettings`, the truth here lives outside the app:
/// LaunchServices decides whether the app actually opens at login, and the user
/// can change that from System Settings → General → Login Items without the app
/// being involved. So this controller keeps two layers:
///
/// * **actual** — `SMAppService.mainApp.status`, re-read on launch and whenever
///   the settings window comes forward. This is what the toggle renders.
/// * **intent** — a `UserDefaults` flag recording what the toggle was last known
///   to be. It exists to detect drift, *not* to repair it.
///
/// Reconciliation is deliberately adopt-only: when the two disagree the OS wins
/// and the intent is rewritten to match. The app never registers or unregisters
/// on the user's behalf at launch — a login item the user removed in System
/// Settings must stay removed. See `openspec/changes/add-launch-at-login/design.md`.
///
/// `ObservableObject` rather than the `@Observable` macro, and `@MainActor`, to
/// match `AppSettings` and `MatchStore` at the macOS 13 deployment floor.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    /// What the settings UI needs to render. Collapses `SMAppService.Status`
    /// into the cases the user can actually act on.
    enum State: Equatable {
        /// Registered and active — the app opens at login.
        case enabled
        /// Not registered; the app does not open at login.
        case disabled
        /// Registered, but the user must approve it in System Settings before
        /// it takes effect.
        case requiresApproval
        /// The app isn't running from an `.app` bundle (a bare `swift run`), so
        /// registration can't work at all. The toggle is disabled in this state.
        case unavailable

        /// Whether the toggle should read as on.
        var isOn: Bool { self == .enabled || self == .requiresApproval }
    }

    private enum Key {
        static let intent = "settings.openAtLogin"
    }

    /// The current registration state, as last read from the system.
    @Published private(set) var state: State

    private let defaults: UserDefaults
    private let service: SMAppService

    /// Whether the running code lives inside an `.app` bundle. Registration is
    /// only possible for a bundled app; `dev.sh` builds a real bundle, so only a
    /// bare `swift run` from `.build` lands here.
    private let isBundled: Bool

    init(defaults: UserDefaults = .standard,
         service: SMAppService = .mainApp,
         isBundled: Bool = Bundle.main.bundleURL.pathExtension == "app") {
        self.defaults = defaults
        self.service = service
        self.isBundled = isBundled
        // Seed from the system rather than from the stored intent, so the very
        // first render is already truthful.
        self.state = isBundled ? Self.state(for: service.status) : .unavailable
    }

    /// The user's last recorded intent. Absent means off — the app never adds
    /// itself to Login Items unless asked.
    private var intent: Bool {
        get { defaults.bool(forKey: Key.intent) }
        set { defaults.set(newValue, forKey: Key.intent) }
    }

    // MARK: - Reading system state

    /// Re-read the system's registration state into `state`.
    func refresh() {
        guard isBundled else {
            state = .unavailable
            return
        }
        state = Self.state(for: service.status)
    }

    /// Launch-time reconciliation. Adopt-only: when the system's state disagrees
    /// with the stored intent, the intent is rewritten to match the system. The
    /// registration itself is never touched here — notably, an intent of `true`
    /// against an unregistered app means the user removed the login item
    /// themselves, and restoring it would override that choice.
    func reconcile() {
        refresh()
        guard state != .unavailable else { return }
        let actual = state.isOn
        if intent != actual { intent = actual }
    }

    // MARK: - Changing the registration

    /// Turn opening at login on or off. Persists the intent and re-reads the
    /// system state afterward, so `state` always reflects what the OS actually
    /// holds rather than what was asked for.
    ///
    /// Failures are swallowed deliberately: a rejected registration must not
    /// take the app down, and the refresh below leaves the toggle showing the
    /// true state rather than the requested one.
    func setEnabled(_ enabled: Bool) {
        guard isBundled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            intent = enabled
        } catch {
            // Leave `intent` alone — `refresh()` below decides what's true.
            NSLog("LaunchAtLogin: \(enabled ? "register" : "unregister") failed: \(error)")
        }
        refresh()
    }

    /// Open System Settings → General → Login Items, so the user can grant a
    /// pending approval or inspect the entry themselves.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Mapping

    private static func state(for status: SMAppService.Status) -> State {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        // `notFound` means the system has no record of this bundle. For the
        // user, that is indistinguishable from "not registered".
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }
}
