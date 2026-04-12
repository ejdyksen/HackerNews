# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

iOS client for Hacker News, built with SwiftUI. Scrapes the HN website directly using HTML parsing (Fuzi 3.1.3) rather than the Firebase API. Originally hand-written, no AI involvement in initial development. AI-assisted development began April 2026.

- **Target**: iOS 26+
- **Language**: Swift / SwiftUI
- **Dependency**: [Fuzi](https://github.com/cezheng/Fuzi) 3.1.3 — XPath/CSS HTML parsing
- **No tests** exist currently

## Active Work

See `TODO.md` for the full feature roadmap. Check it at the start of each session to understand current priorities.

## Build & Run

Open `HackerNews.xcodeproj` in Xcode and run on simulator or device. No external build tools. SPM packages are managed by Xcode.

Use the Xcode MCP server (`mcp__xcode__BuildProject`, `mcp__xcode__XcodeListNavigatorIssues`) to build and check for issues without needing a human at the keyboard. Get the tab identifier first with `mcp__xcode__XcodeListWindows`.

## File Map

```
HackerNews/
├── HackerNewsApp.swift              Entry point; root is AdaptiveHomeView, attaches .handleURLs()
├── App/
│   ├── AdaptiveHomeView.swift       Root view: NavigationSplitView (iPad) or HomeView (iPhone)
│   └── URLHandler.swift             ViewModifier intercepting openURL → in-app sheet WebView
├── Controllers/
│   ├── RequestController.swift      HTTP client (rate limit, retry, Fuzi parse)
│   └── AuthController.swift         Login/logout, cookie persisted in Keychain
├── Model/
│   ├── HNListing.swift              Feed (news/ask/show/newest/jobs), paginated item list
│   ├── HNItem.swift                 Story: metadata + flat comment list, paginates its own comments
│   └── HNComment.swift              Comment node: rich text, tree structure, up/downvote
├── Home/
│   ├── HomeView.swift               iPhone-only: NavigationStack with listing type menu
│   └── LoginView.swift              Sheet: username/password form
├── Listings/
│   ├── ListingView.swift            List + per-type wrappers (NewsListing, AskListing, …)
│   └── ListingItemCell.swift        Row: title + domain, subheading, comment count
├── Comments/
│   ├── ItemDetailView.swift         ScrollView: header + flat LazyVStack comment list
│   ├── ItemDetailHeader.swift       Story title/link (NavigationLink), subheading, body text
│   └── CommentCell.swift            Flat (non-recursive) cell: collapse/expand, vote context menu
├── WebView/
│   ├── WebView.swift                SwiftUI shell with back/fwd/share/safari toolbar
│   ├── WebViewWrapper.swift         UIViewRepresentable wrapping WKWebView
│   ├── WebViewCoordinator.swift     WKNavigationDelegate → updates WebViewState
│   └── WebViewState.swift           @Published state: loading, canGoBack/Fwd, url, pageTitle
├── UIKit Views/
│   └── ActivityView.swift           UIActivityViewController wrapper
└── Preview Content/
    └── PreviewData.swift            Static HNItem/HNListing/HNComment fixtures + extensions
```

## Architecture

### Data Flow

```
URLSession (RequestController) → HTMLDocument (Fuzi)
  → HNListing.parseItems() → [HNItem]           (listing feed)
  → HNItem.loadMoreContent() → [HNComment]       (comment tree)
  → HNComment.createCommentTree()                (tree assembly)
  → HNItem.buildFlatComments()                   (pre-order flatten for display)
```

All network calls use `async/await`. Models are `ObservableObject` with `@Published` properties. UI updates are dispatched to `MainActor.run {}`.

### Navigation

**All navigation is value-based** (`NavigationLink(value:)` + `navigationDestination(for:)`). Do not mix with old-style `NavigationLink(destination:)` in the same NavigationStack — SwiftUI cannot resolve destinations correctly when styles are mixed.

**iPhone path** (compact size class → `HomeView`):
```
HomeView (NavigationStack)
  → NavigationLink(value: ListingType) → listing view
    → NavigationLink(value: HNItem)    → ItemDetailView
      → NavigationLink(value: URL)     → WebView
```
Destination registrations: `ListingType` in `HomeView`, `HNItem` in `ListingView`, `URL` in `ItemDetailView`.

**iPad path** (regular size class → `AdaptiveHomeView`):
```
NavigationSplitView
  ├── Sidebar: List(selection: $selectedListing) — ListingType picker
  ├── Content: ListingContentColumn — Button rows set $selectedItem
  └── Detail: NavigationStack.id(selectedItem?.id)
        └── ItemDetailView → NavigationLink(value: URL) → WebView
```

The `.id(selectedItem?.id)` on the detail `NavigationStack` is intentional and important: it forces SwiftUI to recreate the stack (clearing any pushed WebView) whenever the selected story changes. Do not remove it.

**URL handling**: `URLHandler` (attached at app root) intercepts all `openURL` calls and presents a WebView sheet. This handles links in comment `AttributedString` text. The story title in `ItemDetailHeader` uses `NavigationLink(value: URL)` (push, not sheet) — these are separate paths.

### Comment Rendering

Comments are stored as a tree (`HNItem.rootComments: [HNComment]`, each with `children: [HNComment]`) but displayed as a **pre-order flat list** (`HNItem.flatComments: [HNComment]`). `flatComments` is a `@Published` stored property, recomputed in the same `MainActor.run` block where `rootComments` updates — not a computed property.

`ItemDetailView` maintains `@State private var collapsedIDs: Set<Int>`. Visibility is determined by an O(n) sweep in `visibleComments`: a comment is hidden if any ancestor's id is in `collapsedIDs` (tracked via `hiddenBelowLevel`). `CommentCell` is flat — no recursive children `ForEach`.

### Controllers (singletons)

**RequestController.shared**
- Spoofs a Mobile Safari user-agent string
- Rate limits: enforces ≥1 second between requests to the same endpoint
- Retries: only on HTTP 503, up to 3 times with exponential backoff (1s, 2s, 4s)
- Returns `HTMLDocument`; all other errors are typed `RequestError`

**AuthController.shared**
- `login()`: POST to `/login`, detects success by presence of a `"user"` cookie
- Cookie value stored in Keychain under key `"user_session_cookie"`
- On init, restores cookie into `HTTPCookieStorage` so subsequent requests are authenticated
- Username extraction from cookie: `components(separatedBy: "&").first` — fragile if HN changes cookie format

## HTML Parsing Reference

HN's HTML structure drives all parsing. When HN changes their markup, update the selectors below. Selectors verified against live HN HTML, April 2026.

### Listing page (`/news`, `/ask`, etc.)

| Data | Selector |
|------|----------|
| Story rows | `tr.athing` |
| Adjacent metadata row | `./following-sibling::tr[1]` (XPath) |
| Title + link | `.//*[@class='titleline']//a` (XPath) |
| Domain | `.sitestr` |
| Age | `.age` |
| Score | `.score` → `prefix(while: isNumber)` parsed as `Int` |
| Author | `.hnuser` |
| Comment count | `.//a[contains(text(), 'comment') or text()='discuss']` (XPath); count extracted with `prefix(while: isNumber)` to handle `&nbsp;` separator |
| Pagination "More" link | `a.morelink` |

Next-page URL: `URL(string: href, relativeTo: listingBaseURL)?.absoluteString` — the href is query-only (`?p=2`) and must be resolved relative to the listing's base URL, not the root.

### Item page (`/item?id=N&p=N`)

| Data | Selector |
|------|----------|
| Story body (Ask/Show HN) | `table.fatitem .commtext` — absent for link-only stories |
| Comment rows | `table.comment-tree tr.athing` |
| More comments link | `.morelink` |

### Comment node

| Data | Selector |
|------|----------|
| Text content | `.commtext` |
| Author | `.comhead .hnuser` |
| Age | `.comhead .age` |
| Indent level | `.ind` → `indent` attribute (integer, e.g. `indent="2"`) |
| Upvote auth link | `#up_<id>` href → `auth` query param via `URLComponents` |
| Downvote auth link | `#down_<id>` href → `auth` query param via `URLComponents` |

Note: Downvote links may not be present in HTML for all users/comments (permission-dependent). Always handle nil gracefully.

### Comment Rich Text (`HNComment.parseText`)

Walks `.commtext` child nodes and builds an `AttributedString`:
- `p` → double newline before (if result non-empty)
- `i` → `.italicSystemFont`
- `pre` / `code` → double newline before, `.monospacedSystemFont`
- `a` → link + blue foreground, href truncated to 50 chars for display text

### Comment Tree Assembly (`HNComment.createCommentTree`)

Comments arrive as a flat document-order list. The `indent` attribute on `.ind` gives nesting depth (0 = root). Assembly:
```swift
lastCommentAtLevel[indentLevel - 1]  // parent lookup
```
Level-0 comments become `rootComments` on the item. After assembly, `HNItem.buildFlatComments()` does a pre-order traversal to produce the display-ready flat array.

## UI Patterns

### ListingItemCell

Two structs: `ListingItemCellContent` (pure layout, no navigation) and `ListingItemCell` (wraps content in `NavigationLink(value: item)`). `ListingContentColumn` (iPad) uses `ListingItemCellContent` directly inside a `Button`.

Title and domain are composed inline using SwiftUI `Text` concatenation:
```swift
Text("\(item.title)\(Text(item.domainString).font(.caption)...)")
```

### CommentCell

- **Flat** — does not render `comment.children`. The parent (`ItemDetailView`) renders all comments in a single `LazyVStack` over `visibleComments`.
- Tap header to collapse/expand. Collapsed state shows truncated content instead of age.
- Indent via `CGFloat(comment.indentLevel * 12)` leading padding.
- Long-press context `Menu` exposes upvote/downvote/unvote when `canUpvote` is true.
- Vote state stored as `@Published isUpvoted / isDownvoted` on `HNComment`.

### WebView

- `WebViewWrapper` is the `UIViewRepresentable` (previously had a typo: `WebViewWraper`)
- `WebViewState` holds observable state; `WebViewCoordinator` is the `WKNavigationDelegate`
- Coordinator holds `webViewState` as a plain `var` (not `@ObservedObject` — NSObject subclasses don't participate in SwiftUI observation)
- Toolbar: back, forward, share (uses `webViewState.url`), open-in-Safari

## Known Issues / Technical Debt

1. **HNItem pagination not reset**: `currentPage` and `canLoadMore` are never reset when the same item is viewed a second time. Second viewing starts pagination from where it left off. No pull-to-refresh on `ItemDetailView` yet.
2. **Silent network errors**: errors in `HNItem.loadMoreContent()` and `HNListing` are caught and discarded with `print(error)`. No user-facing error state.
3. **AuthController username parse**: `components(separatedBy: "&").first` — fragile against HN cookie format changes.
4. **RequestController thread safety**: `rateLimitQueue: [String: Date]` is mutated from concurrent async tasks with no synchronization. Low practical risk but not actor-safe.

## Preview Data

`PreviewData.swift` provides:
- `itemOne`, `itemTwo`, `sampleItems` — static `HNItem` instances
- `HNListing.exampleService()` — pre-populated listing
- `HNItem.itemWithComments()` — item with a 3-comment thread (dang → tptacek → patio11)
- `createCommentContent(_:)` — parses HTML strings into `AttributedString` for preview fixtures
