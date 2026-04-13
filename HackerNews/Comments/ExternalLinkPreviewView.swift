// Square external-link preview shown in the item header for non-HN story URLs.
import SwiftUI

struct ExternalLinkPreviewView: View {
    let url: URL
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ExternalLinkPreviewSquare(
            preview: cache.linkPreview(for: url),
            url: url
        )
    }
}

private struct ExternalLinkPreviewSquare: View {
    @ObservedObject var preview: LinkPreview
    let url: URL
    @Environment(\.openURL) private var openURL
    private let size: CGFloat = 76

    var body: some View {
        Button {
            openURL(url)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .task(id: url) {
            preview.loadInitialContent()
        }
        .accessibilityLabel("Open story link preview")
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            background
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )

            externalLinkBadge
                .padding(6)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch preview.state {
        case .idle, .loading:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }

        case .loaded(let image, let kind):
            if kind == .richImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
            }

        case .unavailable:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var externalLinkBadge: some View {
        Image(systemName: "arrow.up.right.square.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(5)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
