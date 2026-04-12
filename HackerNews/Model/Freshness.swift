// Shared freshness thresholds for deciding when listings and item threads
// should be refreshed after navigation or app foregrounding.
import Foundation

enum Freshness: Equatable {
    case fresh
    case aging(Date)
    case stale

    static let freshThreshold: TimeInterval = 60 * 5
    static let staleThreshold: TimeInterval = 60 * 60
    static let navigationRefreshThreshold: TimeInterval = 60

    init(for date: Date?, now: Date = .now) {
        guard let date else {
            self = .stale
            return
        }
        let age = now.timeIntervalSince(date)
        if age < Self.freshThreshold {
            self = .fresh
        } else if age < Self.staleThreshold {
            self = .aging(date)
        } else {
            self = .stale
        }
    }

    var isAging: Bool {
        if case .aging = self { return true }
        return false
    }

    var agingDate: Date? {
        if case .aging(let d) = self { return d }
        return nil
    }

    var debugDescription: String {
        switch self {
        case .fresh:
            return "fresh"
        case .aging(let d):
            let age = Int(Date.now.timeIntervalSince(d))
            return "aging(\(age)s)"
        case .stale:
            return "stale"
        }
    }
}
