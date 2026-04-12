// Shared date formatting helpers for Hacker News timestamps, including parsing
// the site-specific `.age` metadata emitted in scraped HTML.
import Foundation
import Fuzi

func relativeTimeString(from date: Date, now: Date = .now) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 { return "just now" }
    let minutes = seconds / 60
    if minutes == 1 { return "1 minute ago" }
    if minutes < 60 { return "\(minutes) minutes ago" }
    let hours = minutes / 60
    if hours == 1 { return "1 hour ago" }
    if hours < 24 { return "\(hours) hours ago" }
    let days = hours / 24
    if days == 1 { return "1 day ago" }
    if days < 30 { return "\(days) days ago" }
    return date.formatted(.dateTime.month(.abbreviated).day().year())
}

/// HN's `.age` span carries a `title` attribute in the form
/// "2026-04-12T18:30:29 1776018629" — local ISO time plus a Unix timestamp.
/// We parse the Unix timestamp since it's timezone-unambiguous.
func hnDate(fromAge element: Fuzi.XMLElement) -> Date? {
    guard let title = element["title"] else { return nil }
    let parts = title.split(separator: " ")
    guard parts.count >= 2, let unix = TimeInterval(parts[1]) else { return nil }
    return Date(timeIntervalSince1970: unix)
}
