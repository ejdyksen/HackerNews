// Three-level freshness model for cached listings, items, and user profiles.
// Levels are framed around session continuity, not raw cache age:
//   .fresh     – recently loaded, no UI affordance needed
//   .stale     – old enough to surface a "last updated" toast; user decides
//   .veryStale – so old that the next foreground triggers a session reset
import Foundation

enum Freshness: Equatable {
    case fresh
    case stale
    case veryStale

    static let staleThreshold: TimeInterval = 60 * 5
    static let veryStaleThreshold: TimeInterval = 60 * 60

    init(for date: Date?, now: Date = .now) {
        guard let date else {
            self = .veryStale
            return
        }
        let age = now.timeIntervalSince(date)
        if age < Self.staleThreshold {
            self = .fresh
        } else if age < Self.veryStaleThreshold {
            self = .stale
        } else {
            self = .veryStale
        }
    }

    var debugDescription: String {
        switch self {
        case .fresh: return "fresh"
        case .stale: return "stale"
        case .veryStale: return "veryStale"
        }
    }
}
