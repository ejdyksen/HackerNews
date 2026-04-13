// Shared date formatting helpers for relative timestamps shown throughout the UI.
import Foundation

enum RelativeTimeStyle {
    case long
    case short
}

func relativeTimeString(from date: Date, now: Date = .now, style: RelativeTimeStyle = .long) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 { return style == .short ? "now" : "just now" }
    let minutes = seconds / 60
    if minutes == 1 { return style == .short ? "1m" : "1 minute ago" }
    if minutes < 60 { return style == .short ? "\(minutes)m" : "\(minutes) minutes ago" }
    let hours = minutes / 60
    if hours == 1 { return style == .short ? "1h" : "1 hour ago" }
    if hours < 24 { return style == .short ? "\(hours)h" : "\(hours) hours ago" }
    let days = hours / 24
    if days == 1 { return style == .short ? "1d" : "1 day ago" }
    if days < 30 { return style == .short ? "\(days)d" : "\(days) days ago" }
    return date.formatted(.dateTime.month(.abbreviated).day().year())
}
