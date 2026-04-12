# HackerNews App — TODO

A roadmap from the current working client to a full-featured HN reader.
Reading experience comes first. Participation features come after the app is a great reader.

---

## Bug Fixes (known issues, fix before adding features)

- [x] **Share sheet** — `WebView.swift:48` hardcodes `apple.com`; replace with `webViewState.url`
- [x] **Deprecated API** — `ActivityView` uses `@Environment(\.presentationMode)`; migrate to `@Environment(\.dismiss)`
- [x] **Non-tappable body links** — `ItemDetailHeader` renders paragraphs as plain `Text`; render as `AttributedString` so links in Ask/Show HN posts are tappable
- [x] **Dead code** — remove `RequestController.showToast()`
- [x] **Typo** — rename `WebViewWraper` → `WebViewWrapper` (file + struct)
- [x] **Duplicate enum** — consolidate `HomeDestination` and `ListingType` (currently mirror each other)
- [x] **Fragile username parse** — `AuthController.loadStoredCookie()` uses `split(separator: "&").first`; parse properly with `URLComponents`
- [x] **Comment count always 0** — `&nbsp;` between number and "comments" not split by `CharacterSet.whitespaces`; fixed with `prefix(while: isNumber)`
- [x] **Broken Ask/Show HN story links** — relative hrefs (`item?id=N`) created unusable URLs; now resolved against HN base
- [x] **Pagination broken for non-news listings** — More link href `?p=2` was concatenated as root URL; now resolved relative to listing base
- [x] **Fragile comment indent** — was dividing spacer image `width` by 40; now reads the explicit `indent` attribute on `.ind`
- [x] **Fragile fatitem body selector** — was using position-based `tr[4]`; now uses `table.fatitem .commtext`
- [x] **More link matched by string** — iterated all `<a>` elements; now uses `a.morelink` CSS selector

---

## Error Handling & Empty States

- [x] Show an error message when a listing or item fails to load (network error, parse failure)
- [x] "No comments yet" empty state in `ItemDetailView`
- [x] Retry button on failed loads
- [ ] Handle the case where login POST succeeds but no `user` cookie is set (e.g. wrong password with no clear feedback path)

---

## Reading Experience

- [ ] **"New comments" highlighting** — track last-seen `commentCount` per story; highlight comments added since last visit
- [ ] **Mark stories as read** — dim/badge visited stories in the listing
- [ ] **Unread count badge** on comment count in `ListingItemCell`
- [ ] **Font size control** — respect Dynamic Type throughout; audit current hardcoded font calls
- [ ] **Reader mode** — option to load article in simplified reader view via `WKWebView` reader mode
- [ ] **Comment search / jump** — search within a comment thread

---

## Navigation & Discovery

- [ ] **Search** — integrate Algolia HN search (`hn.algolia.com/api`) for full-text story and comment search
- [ ] **User profiles** — tap username anywhere → scrape `/user?id=` for bio, karma, submission history
- [ ] **Story from comment** — tap story title in a comment's context to navigate back up
- [ ] **Deep links** — handle `news.ycombinator.com/item?id=N` URLs opened from Safari / share sheet → push `ItemDetailView` instead of opening WebView

---

## Polish & UX

- [ ] **Swipe actions** on listing rows — swipe to upvote, swipe to open in browser
- [x] **Pull-to-refresh on `ItemDetailView`** (currently only on listings)
- [ ] **Scroll-to-top** on nav title tap (standard iOS convention)
- [ ] **Loading skeleton** instead of plain spinner in listing
- [ ] **Open story in Safari** button in `ItemDetailHeader` (alongside the NavigationLink)
- [ ] **Copy link** context menu on stories and comments

---

## iPad & Accessibility

- [x] **iPad split view** — three-column `NavigationSplitView` (sidebar/listing/detail) on `.regular` size class; iPhone keeps existing `NavigationStack` unchanged
- [x] **Flat comment rendering** — replaced recursive `CommentCell` tree with a `LazyVStack` over a pre-order flat list; collapse/expand state centralised in `ItemDetailView`
- [x] **Value-based navigation** — all navigation migrated to `NavigationLink(value:)` + `navigationDestination(for:)` throughout; old-style destination links removed
- [ ] **Keyboard navigation** — arrow keys to move between stories/comments on iPad with keyboard
- [ ] **VoiceOver labels** on vote buttons and collapse/expand controls
- [ ] **Reduced motion** — respect `accessibilityReduceMotion` in comment collapse animation

---

## Settings

- [ ] Settings screen: default listing type, browser choice (in-app vs. Safari), font size override
- [ ] Option to always open links in Safari instead of in-app WebView
- [ ] Option to collapse already-read comment threads by default

---

## Infrastructure / Tech Debt

- [ ] **Caching** — cache listing pages and item pages with short TTL so back-navigation is instant
- [x] **`@MainActor` audit** — annotated `HNListing`, `HNItem`, `HNComment` with `@MainActor`; removed all `await MainActor.run {}` boilerplate; vote methods on `HNComment` now guaranteed to resume on main thread
- [x] **`canLoadMore` reset on reload** — `HNItem` doesn't reset `currentPage` or `canLoadMore` when reloaded
- [x] **Rate-limit UX** — `RequestController` throws `rateLimitExceeded` silently; added `LocalizedError` conformance so user-facing error messages propagate through to UI
- [ ] **Test targets** — add at minimum unit tests for HTML parsing (the code most likely to break when HN changes markup)

---

## Interactions (authenticated)

- [ ] **Vote on stories** — upvote/unvote stories from the listing and detail views (same auth-token pattern as comment voting)
- [ ] **Reply to comments** — POST to `/comment` with `parent` + `text` + `hmac` fields
- [ ] **Post top-level comment** — reply to the story itself from `ItemDetailView`
- [ ] **Submit a story** — form posting to `/submit` (URL or text post)
- [ ] **Submit Ask HN / text post** — text-only variant of submit
- [ ] **Haptic feedback** on votes
