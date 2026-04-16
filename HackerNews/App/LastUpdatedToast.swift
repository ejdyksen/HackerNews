// Toast presentation for staleness affordances. Two styles:
//   .refresh   — listing toast: just says "Refresh", triggers reload on tap
//   .timestamp — item toast: shows "Updated X ago", triggers reload on tap
// Orange tint when veryStale. Dismissible via horizontal swipe.
import SwiftUI

enum ToastStyle {
    case refresh
    case timestamp
}

struct LastUpdatedToast: View {
    let lastUpdated: Date
    let now: Date
    let style: ToastStyle
    let isVeryStale: Bool
    var onRefresh: (() -> Void)?
    @Binding var isDismissed: Bool
    @State private var dragOffset: CGFloat = 0

    private var agoText: String {
        "Updated \(relativeTimeString(from: lastUpdated, now: now))"
    }

    private var foregroundColor: Color {
        isVeryStale ? .orange : .secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            switch style {
            case .refresh:
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                Text("Refresh")
            case .timestamp:
                Image(systemName: "clock")
                    .font(.caption2)
                Text(agoText)
            }
        }
        .font(.caption)
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .offset(x: dragOffset)
        .padding(.bottom, 16)
        .onTapGesture {
            guard let onRefresh else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isDismissed = true
            }
            onRefresh()
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if abs(value.translation.width) > 40 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDismissed = true
                        }
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(style == .refresh ? "Refresh" : "Last updated")
        .accessibilityValue(style == .refresh ? "" : agoText)
        .accessibilityHint(onRefresh != nil ? "Tap to refresh, swipe to dismiss" : "Swipe to dismiss")
    }
}

struct LastUpdatedToastModifier: ViewModifier {
    let lastUpdated: Date?
    let style: ToastStyle
    let source: String
    var onRefresh: (() -> Void)?
    @State private var isDismissed: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: .now, by: 15)) { timeline in
                    let freshness = Freshness(for: lastUpdated, now: timeline.date)
                    let isAged = freshness == .stale || freshness == .veryStale
                    ZStack {
                        if isAged, let date = lastUpdated, !isDismissed {
                            LastUpdatedToast(
                                lastUpdated: date,
                                now: timeline.date,
                                style: style,
                                isVeryStale: freshness == .veryStale,
                                onRefresh: onRefresh,
                                isDismissed: $isDismissed
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear { debugLog("toast/\(source)", "visible") }
                            .onDisappear { debugLog("toast/\(source)", "hidden") }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: isDismissed)
                    .animation(.easeInOut(duration: 0.25), value: lastUpdated)
                }
            }
            .onChange(of: lastUpdated) { _, _ in
                isDismissed = false
            }
    }
}

extension View {
    func lastUpdatedToast(
        _ lastUpdated: Date?,
        style: ToastStyle = .timestamp,
        source: String,
        onRefresh: (() -> Void)? = nil
    ) -> some View {
        modifier(LastUpdatedToastModifier(
            lastUpdated: lastUpdated,
            style: style,
            source: source,
            onRefresh: onRefresh
        ))
    }
}

struct OnForegroundActivationModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { old, new in
            guard new == .active, old != .active else { return }
            action()
        }
    }
}

extension View {
    func onForegroundActivation(_ action: @escaping () -> Void) -> some View {
        modifier(OnForegroundActivationModifier(action: action))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        Text("Content goes here").font(.title)
    }
    .lastUpdatedToast(Date().addingTimeInterval(-30 * 60), source: "preview")
}

#Preview("Refresh toast") {
    LastUpdatedToast(
        lastUpdated: Date().addingTimeInterval(-7 * 60),
        now: .now,
        style: .refresh,
        isVeryStale: false,
        isDismissed: .constant(false)
    )
}

#Preview("Very stale toast") {
    LastUpdatedToast(
        lastUpdated: Date().addingTimeInterval(-90 * 60),
        now: .now,
        style: .timestamp,
        isVeryStale: true,
        isDismissed: .constant(false)
    )
}
