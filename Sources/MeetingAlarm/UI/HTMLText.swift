import AppKit
import Foundation

/// Turns a calendar event's notes into plain text for the day list. Descriptions are
/// often HTML (`<b>`, `<br>`, links, `&nbsp;`); we strip the markup and decode entities so
/// the popover can render them as ordinary, theme-aware text. The rich overlay keeps its
/// own formatted rendering (see `NotesView`).
enum HTMLText {
    static func plain(_ html: String) -> String {
        guard html.contains("<") || html.contains("&"),
              let data = html.data(using: .utf8),
              let ns = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              )
        else { return html.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ns.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
