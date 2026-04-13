// Observable listing state. This model manages pagination and freshness for one
// story feed, while HNRepository handles the actual page fetch and parsing.
import Foundation

enum ListingSection: String {
    case stories = "Stories"
    case lists = "Lists"
}

enum ListingKind: String, CaseIterable, Hashable {
    case news
    case ask
    case show
    case newest
    case jobs
    case front
    case pool
    case invited
    case best
    case active
    case classic

    static let storyKinds: [ListingKind] = [.news, .newest, .ask, .show, .jobs]
    static let listKinds: [ListingKind] = [.front, .pool, .invited, .best, .active, .classic]
    static let extraListKinds: Set<ListingKind> = Set(listKinds)

    var displayName: String {
        switch self {
        case .news: return "Front Page"
        case .ask: return "Ask HN"
        case .show: return "Show HN"
        case .newest: return "New Stories"
        case .jobs: return "Jobs"
        case .front: return "Front"
        case .pool: return "Pool"
        case .invited: return "Invited"
        case .best: return "Best"
        case .active: return "Active"
        case .classic: return "Classic"
        }
    }

    var iconName: String {
        switch self {
        case .news: return "arrow.up.circle"
        case .ask: return "questionmark.bubble"
        case .show: return "eye"
        case .newest: return "clock"
        case .jobs: return "briefcase"
        case .front: return "calendar"
        case .pool: return "arrow.triangle.2.circlepath"
        case .invited: return "envelope"
        case .best: return "star"
        case .active: return "flame"
        case .classic: return "hourglass"
        }
    }

    var section: ListingSection {
        switch self {
        case .news, .ask, .show, .newest, .jobs:
            return .stories
        case .front, .pool, .invited, .best, .active, .classic:
            return .lists
        }
    }

    var explainer: String? {
        switch self {
        case .front:
            return "Front page submissions for a given day."
        case .pool:
            return "Links selected for a second chance at the front page."
        case .invited:
            return "Overlooked links, invited to repost."
        case .best:
            return "Highest-voted recent links."
        case .active:
            return "Most active current discussions."
        case .classic:
            return "Front page as voted by ancient accounts."
        case .news, .ask, .show, .newest, .jobs:
            return nil
        }
    }

    var defaultDestination: HNListingDestination {
        switch self {
        case .news: return .news
        case .ask: return .ask
        case .show: return .show
        case .newest: return .newest
        case .jobs: return .jobs
        case .front: return .front(day: HNListingDestination.todayDayString)
        case .pool: return .pool
        case .invited: return .invited
        case .best: return .best(hours: 48)
        case .active: return .active
        case .classic: return .classic
        }
    }

    var isExtraList: Bool {
        Self.extraListKinds.contains(self)
    }
}

enum HNListingDestination: Hashable {
    case news
    case ask
    case show
    case newest
    case jobs
    case front(day: String)
    case pool
    case invited
    case best(hours: Int)
    case active
    case classic

    static var todayDayString: String {
        dayString(from: .now)
    }

    var kind: ListingKind {
        switch self {
        case .news: return .news
        case .ask: return .ask
        case .show: return .show
        case .newest: return .newest
        case .jobs: return .jobs
        case .front: return .front
        case .pool: return .pool
        case .invited: return .invited
        case .best: return .best
        case .active: return .active
        case .classic: return .classic
        }
    }

    var displayName: String { kind.displayName }

    var iconName: String { kind.iconName }

    var explainer: String? { kind.explainer }

    var endpointURLString: String {
        switch self {
        case .news:
            return "https://news.ycombinator.com/news"
        case .ask:
            return "https://news.ycombinator.com/ask"
        case .show:
            return "https://news.ycombinator.com/show"
        case .newest:
            return "https://news.ycombinator.com/newest"
        case .jobs:
            return "https://news.ycombinator.com/jobs"
        case .front(let day):
            return "https://news.ycombinator.com/front?day=\(day)"
        case .pool:
            return "https://news.ycombinator.com/pool"
        case .invited:
            return "https://news.ycombinator.com/invited"
        case .best(let hours):
            return "https://news.ycombinator.com/best?h=\(hours)"
        case .active:
            return "https://news.ycombinator.com/active"
        case .classic:
            return "https://news.ycombinator.com/classic"
        }
    }

    var logKey: String {
        switch self {
        case .front(let day):
            return "front/\(day)"
        case .best(let hours):
            return "best/\(hours)h"
        default:
            return kind.rawValue
        }
    }

    var frontDay: String? {
        guard case .front(let day) = self else { return nil }
        return day
    }

    var bestHours: Int? {
        guard case .best(let hours) = self else { return nil }
        return hours
    }

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    static func date(from day: String) -> Date? {
        dayFormatter.date(from: day)
    }

    static func frontDayLabel(for day: String) -> String {
        guard let date = date(from: day) else { return day }
        return frontLabelFormatter.string(from: date)
    }

    static func previousDayString(from day: String) -> String? {
        guard
            let date = date(from: day),
            let previous = Calendar.current.date(byAdding: .day, value: -1, to: date)
        else {
            return nil
        }
        return dayString(from: previous)
    }

    static func nextDayString(from day: String) -> String? {
        guard
            let date = date(from: day),
            let next = Calendar.current.date(byAdding: .day, value: 1, to: date)
        else {
            return nil
        }

        let today = Calendar.current.startOfDay(for: .now)
        guard next <= today else { return nil }
        return dayString(from: next)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let frontLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

@MainActor final class HNListing: ObservableObject {
    let destination: HNListingDestination

    @Published var items: [HNItem] = []
    @Published var isLoading = false
    @Published var hasMoreContent = false
    @Published var loadError: String?
    @Published private(set) var lastUpdated: Date?

    private var nextPageURL: String?
    private var loadTask: Task<Void, Never>?
    private var activeLoadID: UUID?
    weak var cache: AppCache?

    init(_ destination: HNListingDestination, cache: AppCache? = nil) {
        self.destination = destination
        self.cache = cache
    }

    func loadInitialContent() {
        if items.isEmpty {
            loadMoreContent()
        }
    }

    func staleRefresh() {
        guard !isLoading else { return }
        // Don't clear `items` up-front: if the refresh fails, the user would
        // be left staring at an empty error screen instead of the previously
        // loaded (but stale) stories. `finishLoad` replaces `items` atomically
        // on success and leaves them untouched on failure.
        loadMoreContent(reload: true)
    }

    func refreshIfStale() {
        if case .stale = Freshness(for: lastUpdated) {
            debugLog("listing/\(destination.logKey)", "stale -> refresh")
            staleRefresh()
        }
    }

    func loadMoreContent(reload: Bool = false) async {
        await startLoad(reload: reload).value
    }

    func loadMoreContent(reload: Bool = false) {
        _ = startLoad(reload: reload)
    }

    @discardableResult
    private func startLoad(reload: Bool) -> Task<Void, Never> {
        if reload {
            loadTask?.cancel()
            loadTask = nil
        } else if let loadTask {
            return loadTask
        }

        if !reload && !hasMoreContent && !items.isEmpty {
            return Task {}
        }

        let isFirstPageFetch = reload || items.isEmpty
        if reload {
            nextPageURL = nil
        }

        let pageURL = nextPageURL
        let loadID = UUID()

        activeLoadID = loadID
        isLoading = true
        loadError = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let page = try await HNRepository.shared.fetchListingPage(
                    destination: self.destination,
                    nextPageURL: pageURL
                )
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    isFirstPageFetch: isFirstPageFetch,
                    result: .success(page)
                )
            } catch is CancellationError {
                self.finishCancellation(loadID: loadID)
            } catch {
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    isFirstPageFetch: isFirstPageFetch,
                    result: .failure(error)
                )
            }
        }

        loadTask = task
        return task
    }

    private func finishLoad(
        loadID: UUID,
        reload: Bool,
        isFirstPageFetch: Bool,
        result: Result<ParsedHNListingPage, Error>
    ) {
        guard activeLoadID == loadID else { return }

        defer {
            loadTask = nil
            isLoading = false
        }

        switch result {
        case .success(let page):
            let newItems = page.items.map { cache?.canonicalize($0) ?? HNItem(parsed: $0) }
            nextPageURL = page.nextPageURL
            hasMoreContent = page.nextPageURL != nil

            if reload {
                items = newItems
            } else {
                items.append(contentsOf: newItems)
            }

            loadError = nil
            if isFirstPageFetch {
                lastUpdated = .now
                debugLog(
                    "listing/\(destination.logKey)",
                    "loaded \(items.count) items\(reload ? " (reload)" : "")"
                )
            }

        case .failure(let error):
            loadError = error.localizedDescription
            debugLog("listing/\(destination.logKey)", "load error: \(error.localizedDescription)")
        }
    }

    private func finishCancellation(loadID: UUID) {
        guard activeLoadID == loadID else { return }
        loadTask = nil
        isLoading = false
    }
}
