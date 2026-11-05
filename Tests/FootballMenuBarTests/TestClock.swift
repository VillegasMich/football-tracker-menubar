import Foundation

/// A clock whose current time each test sets and moves, for the match store's
/// time rules. Hand `now` to the store as its clock: `{ clock.now }`.
@MainActor
final class TestClock {
    private(set) var now: Date

    init(_ now: Date) {
        self.now = now
    }

    /// Moves the clock forward by `interval` (or back, when negative).
    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
