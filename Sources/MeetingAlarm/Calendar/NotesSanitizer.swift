import Foundation

/// Cleans an event description for display. Google Calendar appends its own Meet
/// conference block after a `-::~:~::-` separator ("Join with Google Meet…", "No edites
/// esta sección"); since we surface the join link as a button, we drop that whole block.
enum NotesSanitizer {
    static func clean(_ raw: String?) -> String? {
        guard var text = raw else { return nil }

        // Google appends its Meet block at the end, fenced by a run of "-:~" separators.
        if let separator = text.range(of: "[-:~]{6,}", options: .regularExpression) {
            text = String(text[..<separator.lowerBound])
        }

        // Trim trailing empty <br> runs and whitespace the block left behind.
        text = text.replacingOccurrences(
            of: "(?:\\s|<br\\s*/?>|&nbsp;)+$",
            with: "",
            options: .regularExpression
        )
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
