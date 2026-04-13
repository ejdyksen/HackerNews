// Shared top-of-list context for the HN lists pages, including the brief
// explainer text and any lightweight inline filters.
import SwiftUI

struct ListingContextHeader: View {
    let destination: HNListingDestination
    let onUpdateDestination: (HNListingDestination) -> Void

    private let bestWindows = [24, 48, 168]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let explainer = destination.explainer {
                Text(explainer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            switch destination {
            case .front(let day):
                frontControls(day: day)
            case .best(let hours):
                bestControls(hours: hours)
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func frontControls(day: String) -> some View {
        HStack(spacing: 12) {
            Button {
                if let previousDay = HNListingDestination.previousDayString(from: day) {
                    onUpdateDestination(.front(day: previousDay))
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Text(HNListingDestination.frontDayLabel(for: day))
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 0)

            Button {
                if let nextDay = HNListingDestination.nextDayString(from: day) {
                    onUpdateDestination(.front(day: nextDay))
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(HNListingDestination.nextDayString(from: day) == nil)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func bestControls(hours: Int) -> some View {
        Picker(
            "Window",
            selection: Binding(
                get: { hours },
                set: { onUpdateDestination(.best(hours: $0)) }
            )
        ) {
            ForEach(bestWindows, id: \.self) { window in
                Text(bestWindowLabel(for: window)).tag(window)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func bestWindowLabel(for hours: Int) -> String {
        switch hours {
        case 24: return "24h"
        case 48: return "48h"
        case 168: return "7d"
        default: return "\(hours)h"
        }
    }
}
