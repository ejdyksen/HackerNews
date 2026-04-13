// Lightweight external-site preview fetcher for story headers. It discovers a
// rich image or icon from page metadata and downloads one usable square source.
import Foundation
import Fuzi
import UIKit

struct ResolvedLinkPreview {
    let image: UIImage
    let kind: LinkPreviewAssetKind
}

private struct LinkPreviewCandidate {
    let url: URL
    let kind: LinkPreviewAssetKind
}

actor LinkPreviewService {
    static let shared = LinkPreviewService()

    private let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"

    /// Maximum bytes we'll accept for a single preview asset. The preview
    /// renders at 76×76, so even a generously sized og:image should fit well
    /// under this cap. Enforced both by Content-Length (up-front) and by
    /// body size after download (defensive, in case the header lied).
    private let maxPreviewBytes = 1_048_576

    func fetchPreview(for url: URL) async throws -> ResolvedLinkPreview? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        let pageResponse = try await request(url: url, accept: "text/html,application/xhtml+xml")
        if isImageResponse(pageResponse.response),
           let image = UIImage(data: pageResponse.data) {
            return ResolvedLinkPreview(image: image, kind: .richImage)
        }

        let document = try HTMLDocument(data: pageResponse.data)
        let pageURL = pageResponse.response.url ?? url
        let candidates = previewCandidates(from: document, pageURL: pageURL)

        for candidate in candidates {
            do {
                let imageResponse = try await request(
                    url: candidate.url,
                    accept: "image/*,*/*;q=0.8",
                    referer: pageURL
                )
                guard isImageResponse(imageResponse.response),
                      let image = UIImage(data: imageResponse.data) else {
                    continue
                }
                return ResolvedLinkPreview(image: image, kind: candidate.kind)
            } catch {
                continue
            }
        }

        return nil
    }

    private func previewCandidates(from document: HTMLDocument, pageURL: URL) -> [LinkPreviewCandidate] {
        var candidates: [LinkPreviewCandidate] = []
        var seenURLs = Set<String>()

        func appendCandidate(href: String?, kind: LinkPreviewAssetKind) {
            guard let href = href?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !href.isEmpty,
                  let resolved = resolve(urlString: href, baseURL: pageURL)
            else {
                return
            }

            let key = resolved.absoluteString
            guard !seenURLs.contains(key) else { return }
            seenURLs.insert(key)
            candidates.append(LinkPreviewCandidate(url: resolved, kind: kind))
        }

        for meta in document.css("meta") {
            let property = meta.attr("property")?.lowercased()
            let name = meta.attr("name")?.lowercased()
            let key = property ?? name ?? ""
            switch key {
            case "og:image", "twitter:image", "twitter:image:src":
                appendCandidate(href: meta.attr("content"), kind: .richImage)
            default:
                continue
            }
        }

        for link in document.css("link[rel]") {
            let rel = link.attr("rel")?.lowercased() ?? ""
            if rel.contains("apple-touch-icon") {
                appendCandidate(href: link.attr("href"), kind: .icon)
            }
        }

        for link in document.css("link[rel]") {
            let rel = link.attr("rel")?.lowercased() ?? ""
            if rel.contains("icon") {
                appendCandidate(href: link.attr("href"), kind: .icon)
            }
        }

        if let rootURL = siteRoot(for: pageURL) {
            appendCandidate(
                href: URL(string: "/apple-touch-icon.png", relativeTo: rootURL)?.absoluteString,
                kind: .icon
            )
            appendCandidate(
                href: URL(string: "/favicon.ico", relativeTo: rootURL)?.absoluteString,
                kind: .icon
            )
        }

        return candidates
    }

    private func request(
        url: URL,
        accept: String,
        referer: URL? = nil
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        if let referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200,
              httpResponse.statusCode <= 299,
              !data.isEmpty else {
            throw RequestError.invalidResponse
        }

        if let lengthHeader = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let advertisedLength = Int(lengthHeader),
           advertisedLength > maxPreviewBytes {
            throw RequestError.invalidResponse
        }

        if data.count > maxPreviewBytes {
            throw RequestError.invalidResponse
        }

        return (data, httpResponse)
    }

    private func isImageResponse(_ response: HTTPURLResponse) -> Bool {
        response.value(forHTTPHeaderField: "Content-Type")?
            .lowercased()
            .hasPrefix("image/") == true
    }

    private func resolve(urlString: String, baseURL: URL) -> URL? {
        guard !urlString.hasPrefix("data:") else { return nil }
        if let resolved = URL(string: urlString, relativeTo: baseURL)?.absoluteURL,
           let scheme = resolved.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return resolved
        }
        return nil
    }

    private func siteRoot(for url: URL) -> URL? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        if let port = url.port {
            return URL(string: "\(scheme)://\(host):\(port)")
        }
        return URL(string: "\(scheme)://\(host)")
    }
}
