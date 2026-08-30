import Foundation

/// Finds the best "join" link for a meeting from an explicit URL plus free-text fields
/// (location, notes/description). Pure and unit-testable.
enum MeetingLink {
    private static let preferredHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "meet.jit.si", "around.co"
    ]

    /// All join links, deduped in order: every preferred video-conferencing URL found
    /// (so Meet *and* Zoom both surface), or a single fallback URL if none are preferred.
    static func detectAll(explicit: URL?, texts: [String?]) -> [URL] {
        var candidates: [URL] = []
        if let explicit {
            candidates.append(explicit)
        }
        for text in texts.compactMap(\.self) {
            candidates.append(contentsOf: urls(in: text))
        }
        var seenURL = Set<String>()
        let unique = candidates.filter { seenURL.insert($0.absoluteString).inserted }

        // Keep only genuine join links, then at most one per provider — so a description with a
        // Zoom join link plus its agenda doc and chat link yields a single "Join Zoom" button.
        let joins = unique.filter { isPreferred($0) && isJoinLink($0) }
        guard !joins.isEmpty else { return Array(unique.prefix(1)) }
        var seenProvider = Set<String>()
        return joins.filter { seenProvider.insert(provider(for: $0)).inserted }
    }

    /// All http(s) URLs in `text`, in order.
    static func urls(in text: String) -> [URL] {
        let type = NSTextCheckingResult.CheckingType.link.rawValue
        guard let detector = try? NSDataDetector(types: type) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range)
            .compactMap(\.url)
            .filter { $0.scheme == "http" || $0.scheme == "https" }
    }

    private static func isPreferred(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return preferredHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Whether `url` is a genuine "join" link vs. a same-provider agenda/recording/chat link.
    /// Zoom descriptions bundle a `docs.zoom.us` agenda doc and a `/launch/` chat link next to
    /// the real `/j/` join; only the join should get a button.
    private static func isJoinLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host.hasSuffix("zoom.us") {
            if host.hasPrefix("docs.") {
                return false
            }
            let path = url.path.lowercased()
            return ["/j/", "/w/", "/wc/", "/s/", "/my/"].contains { path.hasPrefix($0) }
        }
        return true
    }

    /// The provider a preferred URL belongs to, so links dedupe one-per-provider.
    private static func provider(for url: URL) -> String {
        guard let host = url.host?.lowercased() else { return url.absoluteString }
        return preferredHosts.first { host == $0 || host.hasSuffix("." + $0) } ?? host
    }
}
