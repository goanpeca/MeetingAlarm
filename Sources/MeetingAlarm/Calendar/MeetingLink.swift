import Foundation

/// Finds the best "join" link for a meeting from an explicit URL plus free-text fields
/// (location, notes/description). Pure and unit-testable.
enum MeetingLink {
    private static let preferredHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "meet.jit.si", "around.co"
    ]

    /// Pick a join link: a preferred video-conferencing URL if one appears anywhere,
    /// otherwise the explicit URL, otherwise the first URL found in the text.
    static func detect(explicit: URL?, texts: [String?]) -> URL? {
        var candidates: [URL] = []
        if let explicit {
            candidates.append(explicit)
        }
        for text in texts.compactMap(\.self) {
            candidates.append(contentsOf: urls(in: text))
        }
        if let preferred = candidates.first(where: isPreferred) {
            return preferred
        }
        return candidates.first
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
