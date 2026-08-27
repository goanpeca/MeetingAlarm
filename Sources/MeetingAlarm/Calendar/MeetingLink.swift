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
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.absoluteString).inserted }
        let preferred = unique.filter(isPreferred)
        return preferred.isEmpty ? Array(unique.prefix(1)) : preferred
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
}
