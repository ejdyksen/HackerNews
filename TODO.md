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

---

## Error Handling & Empty States

- [ ] Show an error message when a listing or item fails to load (network error, parse failure)
- [ ] "No comments yet" empty state in `ItemDetailView`
- [ ] Retry button on failed loads
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
- [ ] **Pull-to-refresh on `ItemDetailView`** (currently only on listings)
- [ ] **Scroll-to-top** on nav title tap (standard iOS convention)
- [ ] **Loading skeleton** instead of plain spinner in listing
- [ ] **Open story in Safari** button in `ItemDetailHeader` (alongside the NavigationLink)
- [ ] **Copy link** context menu on stories and comments

---

## iPad & Accessibility

- [ ] **iPad split view** — sidebar listing + detail column using `NavigationSplitView`
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
- [ ] **`@MainActor` audit** — models dispatch to `MainActor.run {}`; consider annotating the whole model class instead
- [ ] **`canLoadMore` reset on reload** — `HNItem` doesn't reset `currentPage` or `canLoadMore` when reloaded
- [ ] **Rate-limit UX** — `RequestController` throws `rateLimitExceeded` silently; surface it
- [ ] **Test targets** — add at minimum unit tests for HTML parsing (the code most likely to break when HN changes markup)

---

## Interactions (authenticated)

- [ ] **Vote on stories** — upvote/unvote stories from the listing and detail views (same auth-token pattern as comment voting)
- [ ] **Reply to comments** — POST to `/comment` with `parent` + `text` + `hmac` fields
- [ ] **Post top-level comment** — reply to the story itself from `ItemDetailView`
- [ ] **Submit a story** — form posting to `/submit` (URL or text post)
- [ ] **Submit Ask HN / text post** — text-only variant of submit
- [ ] **Haptic feedback** on votes
