import Foundation

/// User-selectable refresh cadence. Each preset maps to a bounded pair of live
/// and idle poll intervals; the floors are intrinsic — the enum simply can't
/// express a sub-floor value, so no runtime clamping is needed. `.balanced` is
/// the default and preserves the app's prior fixed cadence (45s / 10min).
enum RefreshCadence: String, CaseIterable, Sendable {
    case batterySaver
    case balanced
    case aggressive

    /// The default preset, equal to the app's historical fixed cadence.
    static let `default`: RefreshCadence = .balanced

    /// Fast-mode interval, used while something relevant is live.
    var liveInterval: UInt64 {
        switch self {
        case .batterySaver: return 90_000_000_000    // 90s
        case .balanced:     return 45_000_000_000     // 45s
        case .aggressive:   return 20_000_000_000     // 20s
        }
    }

    /// Slow-mode interval, used when nothing relevant is live.
    var idleInterval: UInt64 {
        switch self {
        case .batterySaver: return 1_800_000_000_000  // 30 min
        case .balanced:     return 600_000_000_000     // 10 min
        case .aggressive:   return 300_000_000_000      // 5 min
        }
    }

    /// Human-readable name for the settings picker.
    var displayName: String {
        switch self {
        case .batterySaver: return "Battery Saver"
        case .balanced:     return "Balanced"
        case .aggressive:   return "Aggressive"
        }
    }
}
