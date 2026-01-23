# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS client for Hacker News built with SwiftUI. The app scrapes the HN website directly using HTML parsing (via Fuzi library) rather than using the official Firebase API.

## Build & Run

Open `HackerNews.xcodeproj` in Xcode and run on iOS simulator or device. No external build tools or package managers needed - Swift packages are managed through Xcode.

## Architecture

### Data Flow
- **HTML Scraping**: `RequestController` fetches pages from news.ycombinator.com and returns parsed `HTMLDocument` (Fuzi)
- **Model Parsing**: `HNItem`, `HNComment`, and `HNListing` parse HTML nodes using XPath/CSS selectors
- **State Management**: Models are `ObservableObject` classes with `@Published` properties for SwiftUI binding

### Key Components

**Controllers** (singleton pattern):
- `RequestController.shared` - HTTP requests with rate limiting and retry logic
- `AuthController.shared` - Login state, session cookies stored in Keychain

**Models**:
- `HNListing` - A feed type (news/ask/show/newest/jobs) that loads paginated items
- `HNItem` - A story with metadata; loads its own comments via `loadMoreContent()`
- `HNComment` - Tree structure with `children` array; supports upvote/downvote

**Views**:
- `HomeView` → `ListingView` → `ListingItemCell` → `ItemDetailView` → `CommentCell`
- `WebView` - WKWebView wrapper with back/forward/share toolbar
- `URLHandler` - View modifier that intercepts URL opens and presents in-app WebView

### HTML Parsing Patterns
Models use Fuzi's `firstChild(css:)`, `firstChild(xpath:)`, and `attr()` methods. When HN changes their HTML structure, parsing code in model initializers will need updating.
