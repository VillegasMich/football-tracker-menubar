import Foundation

/// A clock whose current time each test sets and moves, for the match store's
/// time rules. Hand it to the store as its clock: `now: { [clock] in clock.now }`.
@MainActor
final class TestClock {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    /// Moves the clock forward by `interval`.
    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
