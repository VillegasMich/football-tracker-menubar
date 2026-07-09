import Foundation
import Combine

/// Observable, `UserDefaults`-backed store for the user's global configuration:
/// the refresh cadence, the menu bar live-indicator options, and per-team
/// abbreviation overrides. Owned for the app's lifetime and injected into the
/// SwiftUI environment so the store and views can read it.
///
/// Uses `ObservableObject` rather than the `@Observable` macro to keep the
/// macOS 13 deployment floor, consistent with `MatchStore`.
@MainActor
final class AppSettings: ObservableObject {
    /// `UserDefaults` keys. Distinct from the pin keys owned by `MatchStore`.
    private enum Key {
        static let cadence = "settings.refreshCadence"
        static let showLiveIndicator = "settings.showLiveIndicator"
        static let includeMatchMinute = "settings.includeMatchMinute"
        static let showTeamLogos = "settings.showTeamLogos"
        static let abbreviationOverrides = "settings.abbreviationOverrides"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let notifyOnKickoff = "settings.notifyOnKickoff"
        static let notifyOnGoal = "settings.notifyOnGoal"
    }

    /// Selected refresh cadence preset. Persisted by raw string; an unknown
    /// persisted value falls back to the default.
    @Published var cadence: RefreshCadence {
        didSet { defaults.set(cadence.rawValue, forKey: Key.cadence) }
    }

    /// Whether the pinned-match menu bar title shows a live indicator while the
    /// match is in-progress.
    @Published var showLiveIndicator: Bool {
        didSet { defaults.set(showLiveIndicator, forKey: Key.showLiveIndicator) }
    }

    /// Whether the live indicator includes the match minute/status detail.
    /// Subordinate to `showLiveIndicator` — has no effect while it is off.
    @Published var includeMatchMinute: Bool {
        didSet { defaults.set(includeMatchMinute, forKey: Key.includeMatchMinute) }
    }

    /// Whether the pinned-match menu bar title shows team logos/crests (as in
    /// the popover rows) in place of the text abbreviations. Falls back to the
    /// abbreviation for a team whose logo is missing or fails to load.
    @Published var showTeamLogos: Bool {
        didSet { defaults.set(showTeamLogos, forKey: Key.showTeamLogos) }
    }

    /// Per-team abbreviation overrides, keyed by the team's stable ESPN id.
    @Published private(set) var abbreviationOverrides: [String: String] {
        didSet { defaults.set(abbreviationOverrides, forKey: Key.abbreviationOverrides) }
    }

    /// Master switch for pinned-match notifications. When off, no kickoff or
    /// goal notification is posted, regardless of the subordinate toggles.
    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled)
            // Fire only on an off→on transition so an owner (the notifier) can
            // request authorization the moment notifications are switched on.
            if notificationsEnabled && !oldValue { onNotificationsTurnedOn?() }
        }
    }

    /// Whether the pinned match's kickoff posts a notification. Subordinate to
    /// `notificationsEnabled` — no effect while it is off.
    @Published var notifyOnKickoff: Bool {
        didSet { defaults.set(notifyOnKickoff, forKey: Key.notifyOnKickoff) }
    }

    /// Whether the pinned match's goals post a notification. Subordinate to
    /// `notificationsEnabled` — no effect while it is off.
    @Published var notifyOnGoal: Bool {
        didSet { defaults.set(notifyOnGoal, forKey: Key.notifyOnGoal) }
    }

    /// Invoked when `notificationsEnabled` transitions off→on, so the notifier
    /// can request notification authorization at that moment. Set by app wiring.
    var onNotificationsTurnedOn: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Cadence: unknown/missing raw value falls back to the default.
        self.cadence = defaults.string(forKey: Key.cadence)
            .flatMap(RefreshCadence.init(rawValue:)) ?? .default
        // Toggles default to on when no value is persisted. `object(forKey:)`
        // distinguishes "absent" (⇒ default true) from a stored false.
        self.showLiveIndicator = (defaults.object(forKey: Key.showLiveIndicator) as? Bool) ?? true
        self.includeMatchMinute = (defaults.object(forKey: Key.includeMatchMinute) as? Bool) ?? true
        // Logos default to off — text is the historical menu bar look.
        self.showTeamLogos = (defaults.object(forKey: Key.showTeamLogos) as? Bool) ?? false
        // Notification toggles default to on when no value is persisted.
        self.notificationsEnabled = (defaults.object(forKey: Key.notificationsEnabled) as? Bool) ?? true
        self.notifyOnKickoff = (defaults.object(forKey: Key.notifyOnKickoff) as? Bool) ?? true
        self.notifyOnGoal = (defaults.object(forKey: Key.notifyOnGoal) as? Bool) ?? true
        // Overrides: keep only well-formed String:String pairs; anything else
        // is ignored rather than crashing.
        let raw = defaults.dictionary(forKey: Key.abbreviationOverrides) ?? [:]
        self.abbreviationOverrides = raw.compactMapValues { $0 as? String }
    }

    // MARK: - Abbreviation overrides

    /// The abbreviation to display for `team`: the override when a non-blank one
    /// exists for its id, otherwise the team's ESPN-provided abbreviation.
    func effectiveAbbreviation(for team: Team) -> String {
        if let override = abbreviationOverrides[team.id],
           !override.trimmingCharacters(in: .whitespaces).isEmpty {
            return override
        }
        return team.abbreviation
    }

    /// True when `team` currently has an override, so callers can offer a reset.
    func hasOverride(for team: Team) -> Bool {
        abbreviationOverrides[team.id] != nil
    }

    /// Set a team's abbreviation override. An empty or whitespace-only value
    /// clears the override rather than storing a blank abbreviation.
    func setAbbreviation(_ abbreviation: String, for team: Team) {
        let trimmed = abbreviation.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            clearAbbreviation(for: team)
        } else {
            abbreviationOverrides[team.id] = trimmed
        }
    }

    /// Remove a team's override, restoring its ESPN abbreviation.
    func clearAbbreviation(for team: Team) {
        abbreviationOverrides[team.id] = nil
    }
}
