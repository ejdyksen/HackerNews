import SwiftUI

struct LastUpdatedToast: View {
    let lastUpdated: Date
    let now: Date
    @Binding var isDismissed: Bool
    @State private var dragOffset: CGFloat = 0

    private var agoText: String {
        let minutes = Int(now.timeIntervalSince(lastUpdated) / 60)
        if minutes < 1 { return "Updated just now" }
        if minutes == 1 { return "Updated 1 minute ago" }
        if minutes < 60 { return "Updated \(minutes) minutes ago" }
        let hours = minutes / 60
        if hours == 1 { return "Updated 1 hour ago" }
        return "Updated \(hours) hours ago"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(agoText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .offset(y: dragOffset)
        .padding(.bottom, 16)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 20 {
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
        .accessibilityLabel("Last updated")
        .accessibilityValue(agoText)
        .accessibilityHint("Swipe down to dismiss")
    }
}

struct LastUpdatedToastModifier: ViewModifier {
    let lastUpdated: Date?
    let source: String
    @State private var isDismissed: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: .now, by: 15)) { timeline in
                    let freshness = Freshness(for: lastUpdated, now: timeline.date)
                    ZStack {
                        if case .aging(let date) = freshness, !isDismissed {
                            LastUpdatedToast(lastUpdated: date, now: timeline.date, isDismissed: $isDismissed)
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
    func lastUpdatedToast(_ lastUpdated: Date?, source: String) -> some View {
        modifier(LastUpdatedToastModifier(lastUpdated: lastUpdated, source: source))
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

#Preview("Toast only") {
    LastUpdatedToast(
        lastUpdated: Date().addingTimeInterval(-7 * 60),
        now: .now,
        isDismissed: .constant(false)
    )
}
