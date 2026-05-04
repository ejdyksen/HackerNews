# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project Overview

iOS client for Hacker News, built with SwiftUI. The app scrapes the Hacker News website directly using HTML parsing with Fuzi rather than using the Firebase API. Originally hand-written, no AI involvement in initial development. AI-assisted development began April 2026.

- **Target**: iOS 26+
- **Language**: Swift / SwiftUI
- **Dependency**: [Fuzi](https://github.com/cezheng/Fuzi) 3.1.3
- **No tests** exist currently

## Active Work

See `TODO.md` for the full feature roadmap. Check it at the start of each session to understand current priorities.

## Build & Run

Open `HackerNews.xcodeproj` in Xcode and run on simulator or device. No external build tools. Swift Package dependencies are managed by Xcode.

Use the Xcode MCP server to build and inspect issues without needing a human at the keyboard:
- `mcp__xcode__XcodeListWindows`
- `mcp__xcode__BuildProject`
- `mcp__xcode__XcodeListNavigatorIssues`

Operational note: the Xcode MCP only works when the project is already open in Xcode, and it typically requires a fresh human approval each time. If MCP actions appear to hang during initialization, first check whether the project window is open and whether Xcode is waiting for approval.

## File Map

```
HackerNews/
├── HackerNewsApp.swift              Entry point; injects AppState/AppCache; tracks scenePhase for session restart
├── App/
│   ├── AppCache.swift               In-memory cache for canonical items and listing models; markListingsForFreshLoad()
│   ├── AppState.swift               App-wide state: deep-link routing and lastBackgroundedAt for veryStale detection
│   ├── DebugLog.swift               Debug-only logging shim
│   ├── LastUpdatedToast.swift       Toast system with ToastStyle (.refresh/.timestamp), tap-to-refresh, horizontal dismiss
│   ├── RelativeTime.swift           Shared date formatting and HN age parsing
│   └── URLHandler.swift             openURL interceptor that routes HN item links in-app and presents SFSafariViewController for external links
├── Controllers/
│   ├── RequestController.swift      Low-level HTTP transport, rate limiting, retry, cookie helpers
│   ├── AuthController.swift         Login/logout and HN session persistence in Keychain
│   ├── HNRepository.swift           HN-specific endpoint orchestration and vote submission
│   ├── HNHTMLParser.swift           Fuzi-based HTML parsing into lightweight DTOs
│   └── LinkPreviewService.swift     External-site preview discovery and image/icon fetching for story headers
├── Model/
│   ├── HNListing.swift              Listing kinds, parameterized listing destinations, and feed pagination state
│   ├── HNItem.swift                 Story state, metadata, comments, and vote state
│   ├── HNComment.swift              Comment state mapped from parsed comment trees
│   ├── HNUser.swift                 User profile route and observable user-page state
│   ├── LinkPreview.swift            Observable cached state for external story preview images
│   └── Freshness.swift              Three-level freshness model (fresh/stale/veryStale)
├── Home/
│   ├── HomeView.swift               Unified NavigationSplitView root (iPhone collapses via preferredCompactColumn)
│   ├── LoginView.swift              Sheet-based username/password form
│   └── SettingsView.swift           Modal settings sheet; currently only exposes account actions
├── Listings/
│   ├── ListingContentColumn.swift   Listing column used by the unified root, including refresh/toast behavior
│   ├── ListingContextHeader.swift   Shared list explainer/filter header for HN list pages
│   └── ListingItemCell.swift        ListingItemCellContent story row rendering and row-level vote menu
├── Comments/
│   ├── ItemDetailView.swift         Story detail screen with flat comment thread
│   ├── ItemDetailHeader.swift       Story header with title, metadata, and self-post body
│   ├── ExternalLinkPreviewView.swift Square preview affordance for external story links
│   └── CommentCell.swift            Flat comment row with collapse and vote menu
├── Profile/
│   └── UserProfileView.swift        Native Hacker News user profile screen
└── Preview Content/
    └── PreviewData.swift            Static preview fixtures and preview-only helpers
```

## Architecture

### Data Flow

```
URLSession / cookies / retry policy (RequestController)
  → endpoint-level HN operations (HNRepository)
    → parsed DTOs from Fuzi HTML (HNHTMLParser)
      → observable view state (HNListing / HNItem / HNComment)
```

The important boundaries are:
- `RequestController` knows HTTP mechanics, headers, retry, throttling, and cookie access
- `HNRepository` knows which HN pages to fetch and which parser entry point to call
- `HNHTMLParser` knows HN markup and turns it into parsed structs
- Models own UI-facing state, mutation, and in-flight load coordination

All network calls use `async/await`. Core models are `@MainActor ObservableObject` with `@Published` properties.

### Navigation

**All navigation is value-based** using `NavigationLink(value:)` plus `navigationDestination(for:)`. Do not mix it with `NavigationLink(destination:)` inside the same `NavigationStack`.

A single `HomeView` serves both iPhone and iPad:

```
NavigationSplitView(columnVisibility: $columnVisibility,
                    preferredCompactColumn: $preferredCompactColumn)
  ├── Sidebar: ListingKind selection (List(selection: selectedSidebarKind))
  ├── Content: ListingContentColumn sets $selectedItem (List(selection: $selectedItem))
  └── Detail: NavigationStack.id(selectedItem?.id)
        └── ItemDetailView
            └── HNUserRoute → UserProfileView
```

On iPad (regular size class), this renders as a three-column split view. On iPhone (compact), SwiftUI automatically collapses into a single `NavigationStack` where the sidebar is the stack root, and `List(selection:)` bindings drive pushes (sidebar selection → content, item selection → detail).

`preferredCompactColumn` is initialized to `.content` so iPhone users land on the currently selected listing (Front Page by default) rather than the sidebar at launch. Back button reveals the sidebar for listing switching. In compact size classes, `HomeView` clears the sidebar's transient selection when the sidebar becomes visible so selecting the current listing again still pushes the content column.

The `.id(selectedItem?.id)` on the detail `NavigationStack` is intentional and important: it forces SwiftUI to recreate the stack when the selected story changes. Do not remove it casually.

The `columnVisibility = .detailOnly` flip (deep-link item handler, detail full-screen toggle) is a no-op in compact but useful on iPad. `ItemDetailView` only shows the full-screen toolbar button in regular size classes.

### URL Handling

All URLs go through `openURL` and are intercepted by `URLHandler`, which is attached at the app root. HN item URLs become in-app navigation through `AppState.deepLinkItemID`; non-item URLs are opened in `SFSafariViewController`.

There is no separate Safari wrapper file anymore. `URLHandler` presents `SFSafariViewController` directly.

### Listing and Item Loading

Navigation uses two related listing concepts:
- `ListingKind` is the stable menu/sidebar identity (`news`, `ask`, `front`, `best`, etc.)
- `HNListingDestination` is the concrete cached endpoint, including filter state such as `front(day:)` or `best(hours:)`

`AppCache` keys listing models by `HNListingDestination`, not by the broader kind. This lets filtered variants keep separate cached state.

External story link previews are also cached outside `HNItem`. `AppCache` reuses `LinkPreview` objects keyed by story URL, and `LinkPreviewService` fetches page metadata directly from the linked site to resolve an image or icon for `ItemDetailHeader`.

`HNListing` and `HNItem` both use a **single-flight** loading pattern:
- repeated non-reload load requests reuse the active task
- reload requests cancel and replace the active task
- pagination state is updated only by the current active load id

This matters because scroll-triggered pagination and refreshes can overlap if the guardrails are removed.

**Loading methods on models:**

| Method | Purpose | Used by |
|--------|---------|---------|
| `loadInitialContent()` | Load if empty (no freshness check) | `.task(id:)` in listing views — fires on first appear and on nav-pop-back, intentionally no-ops when items exist |
| `loadIfStaleOrMissing()` | Freshness-gated: load if not `.fresh`, clearing stale content first so the spinner shows | Navigation events — tap pre-warm, listing menu/sidebar switch, deep-link handlers |
| `loadMoreContent(reload:)` | Low-level fetch; `reload: true` cancels in-flight and restarts | Pull-to-refresh, pagination, called internally by the methods above |
| `reset()` (HNListing only) | Cancels tasks and clears all state without triggering a fetch | `pendingFreshLoad` flow, `loadIfStaleOrMissing()` internally |

**There are no per-screen auto-refresh hooks.** The old `refreshIfStale()`, `refreshIfOlderThan()`, and `.onForegroundActivation` patterns are all removed. Views do not silently re-fetch on their own. The only automatic refresh trigger is the session-restart flow (see Freshness Model below).

### Freshness Model

`Freshness.swift` defines three levels framed around session continuity:

| Level | Threshold | UI behavior |
|-------|-----------|-------------|
| `.fresh` | < `staleThreshold` (5 min) | Cache trusted. No UI hints. |
| `.stale` | < `veryStaleThreshold` (1 hr) | Toast appears. User decides whether to pull-to-refresh or tap the toast. Listing nav subtitle shows the age. |
| `.veryStale` | ≥ `veryStaleThreshold` | Same toast (orange-tinted). On next app foreground after long backgrounding, listings are marked for fresh reload. |

**Key design principle:** "navigation event" = freshness-gated fetch; "pop-back" = leave the user where they were. Selecting a new item or listing checks freshness and re-fetches if stale. Popping back to a previously-visited screen does nothing — the user sees their scroll position and existing content, plus the toast if it's stale.

**Session restart flow:**
1. `HackerNewsApp` tracks `scenePhase`. On `.background`, records `appState.lastBackgroundedAt`.
2. On next `.active`, if the gap exceeds `veryStaleThreshold`, calls `cache.markListingsForFreshLoad()`, which sets `pendingFreshLoad = true` on every cached `HNListing`.
3. Nothing happens immediately — no navigation is forced.
4. When the user eventually pops back to a listing, `ListingContentColumnBody.onAppear` checks the flag, clears it, and does `reset()` + `loadInitialContent()` — a full fresh reload with spinner.
5. Items and users are NOT eagerly reset. They reload lazily via `loadIfStaleOrMissing()` when next navigated to.

**No state restoration** across app termination. Cold launch always starts on Front Page. If iOS state restoration (`@SceneStorage`) is added later, `lastBackgroundedAt` must be persisted to UserDefaults so the veryStale check survives termination.

### Toast System

`LastUpdatedToast` provides staleness affordances with two styles:

| Style | Label | Used by |
|-------|-------|---------|
| `.refresh` | "↻ Refresh" | Listing views — a call-to-action for the user |
| `.timestamp` | "🕒 Updated X ago" | Item detail view — informational with tap-to-refresh |

Both styles:
- Appear when freshness is `.stale` or `.veryStale`
- Are tappable when an `onRefresh` closure is provided (dismisses toast + fires reload)
- Turn orange when `.veryStale`
- Dismiss via horizontal swipe only (left or right, 40pt threshold) — `.simultaneousGesture` for drag so tap and swipe coexist
- Reset `isDismissed` when `lastUpdated` changes (so the toast reappears after a refresh)

**Listing navigation subtitle:** Both iPhone and iPad listing views use `.navigationSubtitle()` to always show the data age (e.g. "Updated 3 minutes ago"). A `Timer.publish(every: 60)` ticks the age string. A `" "` placeholder is used before the first load to reserve vertical space and prevent the initial scroll offset from shifting when the real text appears.

### Comment Rendering

Comments are stored as a tree in `HNItem.rootComments`, but displayed as a **pre-order flat list** in `HNItem.flatComments`. `HNHTMLParser` assembles the parsed tree, `HNComment.models(from:)` maps it into observable comment objects, and `HNItem.buildFlatComments()` flattens it for display.

`ItemDetailView` maintains `@State private var collapsedIDs: Set<Int>`. Visibility is determined by a simple O(n) sweep over `item.flatComments`, hiding descendants of collapsed comments.

## Shared Singletons

### `RequestController.shared`

- Owns low-level HTTP requests
- Spoofs a Mobile Safari user-agent string
- Enforces a minimum 1 second interval between requests to the same endpoint
- Retries only on HTTP 503, up to 3 times with exponential backoff
- Returns raw `Data`, not parsed HTML
- Exposes helpers for restoring, reading, and clearing the HN session cookie in `HTTPCookieStorage.shared`

### `AuthController.shared`

- Logs in through the real HN `/login` form flow
- Sends `goto`, `Origin`, and `Referer` fields/headers to mimic the web form submission
- Detects login success by presence of the `"user"` cookie
- Stores the cookie value and username separately in Keychain
- Restores the cookie into shared cookie storage on startup

### `HNRepository.shared`

- Fetches listing pages and item pages through `RequestController`
- Delegates HTML parsing to `HNHTMLParser`
- Submits votes using the HN vote endpoints

## HTML Parsing Reference

HN's HTML structure drives all parsing. When HN changes markup, update `HNHTMLParser.swift`.

### Listing Page (`/news`, `/ask`, etc.)

| Data | Selector |
|------|----------|
| Story rows | `tr.athing` |
| Adjacent metadata row | `./following-sibling::tr[1]` |
| Title + link | `.//*[@class='titleline']//a` |
| Domain | `.sitestr` |
| Age | `.age` |
| Score | `.score` |
| Author | `.hnuser` |
| Comment count | `.//a[contains(text(), 'comment') or text()='discuss']` |
| Pagination link | `a.morelink` |

`a.morelink` hrefs are query-relative like `?p=2`, so they must be resolved relative to the listing base URL.

### Item Page (`/item?id=N&p=N`)

| Data | Selector |
|------|----------|
| Story body | `table.fatitem .commtext` |
| Comment rows | `table.comment-tree tr.athing` |
| More comments link | `.morelink` |

### User Page (`/user?id=name`)

| Data | Selector |
|------|----------|
| Username | `//tr[@id='bigbox']//tr[td[1][normalize-space()='user:']]/td[2]//*[@class='hnuser']` |
| Created | `//tr[@id='bigbox']//tr[td[1][normalize-space()='created:']]/td[2]` |
| Karma | `//tr[@id='bigbox']//tr[td[1][normalize-space()='karma:']]/td[2]` |
| About | `//tr[@id='bigbox']//tr[td[1][normalize-space()='about:']]/td[2]` |
| Submissions | `a[href*='submitted?id=']` |
| Comments | `a[href*='threads?id=']` |
| Favorites | `a[href*='favorites?id=']` |

### Comment Node

| Data | Selector |
|------|----------|
| Text content | `.commtext` |
| Author | `.comhead .hnuser` |
| Age | `.comhead .age` |
| Indent level | `.ind` → `indent` attribute |
| Upvote link | `#up_<id>` |
| Downvote link | `#down_<id>` |
| Undo link | `#un_<id>` |

### Vote-State Parsing

Items and comments are not identical here.

For **comments**:
- upvote/downvote state is inferred from the presence and text of `#un_<id>`
- `canResetVote` is true only when `#un_<id>` exists

For **story items**:
- if `#un_<id>` exists, the item is voted and still resettable
- if `#up_<id>` has class `nosee`, the item has already been upvoted even if undo is no longer available
- `canResetVote` is still true only when `#un_<id>` exists

This distinction is important. A story can be `isUpvoted == true` while `canResetVote == false`.

### Rich Text Parsing

`HNHTMLParser.parseCommentText(_:)` walks `.commtext` child nodes into an `AttributedString`:
- `p` → double newline before, if needed
- `i` → italic system font
- `pre` / `code` → monospaced font with spacing before
- `a` → tappable link, blue foreground, truncated display text

### Comment Tree Assembly

Comments arrive as a flat document-order list. `HNHTMLParser.createCommentTree(nodes:)` uses the `.ind` `indent` attribute to rebuild parent/child relationships, then `HNItem.buildFlatComments()` does a pre-order flatten for display.

## UI Patterns

### Listing Rows

`ListingItemCellContent` is the reusable story row. It's wrapped in `NavigationLink(value: item)` inside a `List(selection: $selectedItem)` in `ListingContentColumnBody`. The native split-view selection styling depends on this exact shape — commit `dc3fb08` explicitly tuned it. Do not replace this with a `Button`.

Pre-warm for story fetches is done in `HomeView`'s `.onChange(of: selectedItem?.id)` handler, which calls `selectedItem?.loadIfStaleOrMissing()` synchronously when the `List(selection:)` binding updates — before the detail column's `ItemDetailView` is constructed. This runs identically on both iPad (selection column → detail column) and iPhone compact (selection → pushed detail), so there is only one pre-warm code path.

### Vote Menus

Items and comments expose context menus or menu actions for vote operations. Keep these behaviors aligned with parser state:
- show current vote state using `isUpvoted` / `isDownvoted`
- keep `Unvote` visible when something is voted
- disable `Unvote` when `canResetVote == false`

Do not collapse `isUpvoted` and `canResetVote` into one concept for story items.

### Comment Cells

- `CommentCell` is flat and does not recurse into `children`
- indentation is based on `indentLevel * 12`
- collapse/expand is owned by `ItemDetailView`, not `HNComment`

## Preview Data

`PreviewData.swift` provides:
- `itemOne` — a sample `HNItem`
- `HNItem.itemWithComments()` — item with a 3-comment thread
- `createCommentContent(_:)` — preview helper using `HNHTMLParser.parseCommentText(_:)`

## Agent Notes

- Prefer updating `AGENTS.md` when architecture changes. It is intended to stay operationally accurate, not just descriptive.
- If auth stops working, compare against the live HN form submission before simplifying headers or cookie handling.
- The repo still has no tests, so build verification and careful HTML reasoning matter more than usual.
- If Xcode MCP appears stuck during startup, remind the human that the project usually needs to be open already and that Xcode may be waiting on another approval prompt.
- `ScrollPosition.scrollTo(edge:)` does **not** work reliably with `List`. Use `ScrollViewReader` + `proxy.scrollTo(id:anchor:)` for any `List` scrolling. `ScrollPosition` works fine with `ScrollView` (e.g. `ItemDetailView`). The listing views currently use `ScrollViewReader` for toast-triggered scroll-to-top.
- The listing scroll-to-top on toast refresh uses a 0.35s `DispatchQueue.main.asyncAfter` delay before the reload to prevent the reload's `isLoading = true` state change from interrupting the scroll animation mid-flight.
- Do not add per-screen `.onForegroundActivation` refresh hooks. The old pattern of `refreshIfStale()` on foreground is intentionally removed. Freshness-gated loading only happens at explicit navigation events; the session-restart flow handles long-backgrounding scenarios.
