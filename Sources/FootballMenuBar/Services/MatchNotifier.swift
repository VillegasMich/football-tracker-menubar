import Foundation
import UserNotifications

/// Posts native macOS notifications for the pinned match: one when it kicks off
/// (`upcoming → inProgress`) and one when its score increases while live.
///
/// Events are detected by diffing each newly observed pinned-match snapshot
/// against a retained `baseline`. Only poll-driven updates go through
/// `evaluate(_:)`; seeding paths (pin, launch restore, unpin) go through
/// `seed(_:)`, which updates the baseline WITHOUT notifying — so launching the
/// app, pinning, or re-pinning never fires a notification for events that
/// happened before or outside live observation.
///
/// `@MainActor` to match `MatchStore`, which drives it.
@MainActor
final class MatchNotifier {
    /// Which side of a match scored — the side whose goal count increased.
    enum ScoringSide { case home, away }

    private let settings: AppSettings
    private let center: UNUserNotificationCenter

    /// Last observed pinned-match snapshot, the reference for the next diff.
    /// `nil` means "no reference yet" (first sight ⇒ seed, don't notify).
    private var baseline: Match?

    /// Guards against re-prompting for authorization once we've asked.
    private var didRequestAuthorization = false

    init(settings: AppSettings, center: UNUserNotificationCenter = .current()) {
        self.settings = settings
        self.center = center
        // Request when notifications are switched on later…
        settings.onNotificationsTurnedOn = { [weak self] in
            self?.requestAuthorizationIfNeeded()
        }
        // …and now, if they are already enabled at launch.
        requestAuthorizationIfNeeded()
    }

    // MARK: - Authorization

    /// Ask the system for permission to deliver notifications, at most once and
    /// only while notifications are enabled. A denial simply means later posts
    /// are dropped by the system; nothing crashes.
    func requestAuthorizationIfNeeded() {
        guard settings.notificationsEnabled, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        // Use the async API rather than the completion-handler form. Because this
        // type is `@MainActor`, a trailing closure would inherit main-actor
        // isolation, but `requestAuthorization`'s completion handler is invoked on
        // a background queue — tripping a libdispatch main-thread assertion
        // (SIGTRAP) the moment authorization resolves. `await` hops actors safely.
        let center = self.center
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    // MARK: - Baseline updates

    /// Seed the baseline without notifying (pin, launch restore, unpin).
    func seed(_ match: Match?) {
        baseline = match
    }

    /// Compare a poll-driven snapshot against the baseline, post any warranted
    /// notification, then adopt it as the new baseline. The baseline is updated
    /// on every path — including when an event type is disabled — so toggling a
    /// type back on never replays events missed while it was off.
    func evaluate(_ new: Match?) {
        defer { baseline = new }

        // First sight, pin cleared, or a switch to a different match: seed only.
        guard let new, let base = baseline, base.id == new.id else { return }

        // Kickoff: the match was upcoming and is now in progress.
        if base.state == .upcoming, new.state == .inProgress {
            postKickoff(new)
        }

        // Goal: both snapshots live and the score went up. At most one
        // notification per evaluation; a decrease (VAR/correction) notifies
        // nothing and just re-baselines via the deferred assignment above.
        if base.state == .inProgress, new.state == .inProgress {
            if new.score.home > base.score.home {
                postGoal(new, scoringSide: .home)
            } else if new.score.away > base.score.away {
                postGoal(new, scoringSide: .away)
            }
        }
    }

    // MARK: - Posting

    /// Post the kickoff notification, if enabled. Names both teams.
    private func postKickoff(_ match: Match) {
        guard settings.notificationsEnabled, settings.notifyOnKickoff else { return }
        post(title: "Kick-off",
             body: "\(match.home.name) vs \(match.away.name)",
             id: "kickoff-\(match.id)")
    }

    /// Post the goal notification, if enabled. Identifies the match, the scoring
    /// team, and the new current score.
    private func postGoal(_ match: Match, scoringSide: ScoringSide) {
        guard settings.notificationsEnabled, settings.notifyOnGoal else { return }
        let scorer = scoringSide == .home ? match.home : match.away
        post(title: "Goal — \(scorer.name)",
             body: "\(match.home.name) \(match.score.home) – \(match.score.away) \(match.away.name)",
             // Include the score so rapid goals produce distinct notifications.
             id: "goal-\(match.id)-\(match.score.home)-\(match.score.away)")
    }

    /// Deliver a plain notification. No `categoryIdentifier`/actions and no
    /// response handling, so clicking it does nothing beyond dismissal.
    private func post(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // nil trigger ⇒ deliver immediately.
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
}
