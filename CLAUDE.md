# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

iOS client for Hacker News, built with SwiftUI. Scrapes the HN website directly using HTML parsing (Fuzi 3.1.3) rather than the Firebase API. Originally hand-written, no AI involvement in initial development.

- **Target**: iOS 26+
- **Language**: Swift / SwiftUI
- **Dependency**: [Fuzi](https://github.com/cezheng/Fuzi) 3.1.3 — XPath/CSS HTML parsing
- **No tests** exist currently

## Active Work

See `TODO.md` for the full feature roadmap. Check it at the start of each session to understand current priorities.

## Build & Run

Open `HackerNews.xcodeproj` in Xcode and run on simulator or device. No external build tools. SPM packages are managed by Xcode.

## File Map

```
HackerNews/
├── HackerNewsApp.swift              Entry point; attaches .handleURLs() to root
├── App/
│   └── URLHandler.swift             ViewModifier intercepting openURL → in-app sheet WebView
├── Controllers/
│   ├── RequestController.swift      HTTP client (rate limit, retry, Fuzi parse)
│   └── AuthController.swift         Login/logout, cookie persisted in Keychain
├── Model/
│   ├── HNListing.swift              Feed (news/ask/show/newest/jobs), paginated item list
│   ├── HNItem.swift                 Story: metadata + comment tree, paginates its own comments
│   └── HNComment.swift              Comment node: rich text, tree structure, up/downvote
├── Home/
│   ├── HomeView.swift               Navigation menu + login/logout section
│   └── LoginView.swift              Sheet: username/password form
├── Listings/
│   ├── ListingView.swift            List + per-type wrappers (NewsListing, AskListing, …)
│   └── ListingItemCell.swift        Row: title + domain, subheading, comment count
├── Comments/
│   ├── ItemDetailView.swift         Scroll view: header + paginating comment tree
│   ├── ItemDetailHeader.swift       Story title/link, subheading, body paragraphs
│   └── CommentCell.swift            Recursive cell: collapse/expand, vote context menu
├── WebView/
│   ├── WebView.swift                SwiftUI shell with back/fwd/share/safari toolbar
│   ├── WebViewWraper.swift          UIViewRepresentable wrapping WKWebView (typo in name)
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
```

All network calls use `async/await`. Models are `ObservableObject` with `@Published` properties. UI updates are dispatched to `MainActor.run {}`.

### Navigation

- `NavigationStack` with a `HomeDestination` enum for typed push navigation
- Tapping a story pushes `ItemDetailView`; the story link inside pushes `WebView`
- Any `openURL` call app-wide is intercepted by `URLHandler` and presented as a sheet containing a `NavigationView` + `WebView`

### Controllers (singletons)

**RequestController.shared**
- Spoofs a Mobile Safari user-agent string
- Rate limits: enforces ≥1 second between requests to the same endpoint
- Retries: only on HTTP 503, up to 3 times with exponential backoff (1s, 2s, 4s)
- Returns `HTMLDocument`; all other errors are typed `RequestError`
- Contains dead code: `showToast()` — never called, can be removed

**AuthController.shared**
- `login()`: POST to `/login`, detects success by presence of a `"user"` cookie
- Cookie value stored in Keychain under key `"user_session_cookie"`
- On init, restores cookie into `HTTPCookieStorage` so subsequent requests are authenticated
- Username extraction from cookie value uses `.split(separator: "&").first` — fragile, may break if HN changes cookie format

## HTML Parsing Reference

HN's HTML structure drives all parsing. When HN changes their markup, update the selectors below.

### Listing page (`/news`, `/ask`, etc.)

| Data | Selector |
|------|----------|
| Story rows | `tr.athing` |
| Adjacent metadata row | `./following-sibling::tr[1]` (XPath) |
| Title + link | `.//*[@class='titleline']//a` |
| Domain | `.sitestr` |
| Age | `.age` |
| Score | `.score` → first word parsed as `Int` |
| Author | `.hnuser` |
| Comment count | `//a[contains(text(), 'comment') or text()='discuss']` |
| Pagination "More" link | `a` elements where `stringValue == "More"` |

### Item page (`/item?id=N&p=N`)

| Data | Selector |
|------|----------|
| Story body paragraphs | `//table[@class="fatitem"]//tr[4]` child nodes |
| Comment rows | `table.comment-tree tr.athing` |
| More comments link | `.morelink` |

### Comment node

| Data | Selector |
|------|----------|
| Text content | `.commtext` |
| Author | `.comhead .hnuser` |
| Age | `.comhead .age` |
| Indent level | `.ind img[width]` ÷ 40 |
| Upvote auth link | `#up_<id>` href, `auth` query param |
| Downvote auth link | `#down_<id>` href, `auth` query param |

### Comment Rich Text (`HNComment.parseText`)

Walks `.commtext` child nodes and builds an `AttributedString`:
- `p` → double newline before
- `i` → `.italicSystemFont`
- `pre` / `code` → double newline before, `.monospacedSystemFont`
- `a` → link + blue foreground, truncated to 50 chars for display

### Comment Tree Assembly

Comments arrive as a flat list sorted by document order. Indent level is used to re-establish parent-child relationships:
```swift
lastCommentAtLevel[indentLevel - 1]  // parent lookup
```
Level-0 comments become `rootComments` on the item.

## UI Patterns

### ListingItemCell

Title and domain are composed inline using SwiftUI's `Text` + `Text` concatenation:
```swift
Text("\(item.title)\(Text(item.domainString).font(.caption)...)")
```

### CommentCell

- Tap to collapse/expand (animated). Collapsed state shows first 50 chars of content in place of age.
- Indent via `CGFloat(comment.indentLevel * 12)` leading padding
- Long-press (context `Menu`) exposes upvote/downvote/unvote when `canUpvote` is true
- Vote icons (thumbs up/down fill) appear in the comment header when voted
- Recursively renders `comment.children`

### WebView

- `WebViewWraper` (note typo) is the `UIViewRepresentable`
- `WebViewState` holds observable state; `WebViewCoordinator` is the `WKNavigationDelegate`
- Toolbar: back, forward, share, open-in-Safari
- **Known bug**: share sheet hardcodes `URL(string: "https://www.apple.com")!` instead of `webViewState.url`

## Known Issues / Technical Debt

1. **Share sheet bug**: `WebView.swift:48` — share button always shares `apple.com`, not the current page URL
2. **Dead code**: `RequestController.showToast()` — never called
3. **Fragile username parse**: `AuthController.loadStoredCookie()` extracts username via `split(separator: "&").first`
4. **Typo**: `WebViewWraper` (missing 'p') in filename and struct name
5. **ActivityView**: uses deprecated `presentationMode` environment value
6. **Duplicate enum**: `HomeDestination` in `HomeView.swift` mirrors `ListingType` in `HNListing.swift`
7. **iOS body text**: `ItemDetailHeader` renders `item.paragraphs` as plain `Text` — links in Ask HN/Show HN body text are not tappable
8. **No error UI**: network errors are silently swallowed in most paths

## Preview Data

`PreviewData.swift` provides:
- `itemOne`, `itemTwo`, `sampleItems` — static `HNItem` instances
- `HNListing.exampleService()` — pre-populated listing
- `HNItem.itemWithComments()` — item with a 3-comment thread (dang → tptacek → patio11)
- `createCommentContent(_:)` — parses HTML strings into `AttributedString` for preview fixtures
