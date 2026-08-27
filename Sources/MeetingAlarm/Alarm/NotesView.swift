import AppKit
import SwiftUI

/// Renders an event's notes/description. Calendar notes are often HTML (`<b>`, `<br>`,
/// links), so we parse them to an `AttributedString` once and show formatted text.
struct NotesView: View {
    let html: String

    @State private var rendered: AttributedString?

    var body: some View {
        Group {
            if let rendered {
                Text(rendered)
            } else {
                Text(html) // fallback until parsed
            }
        }
        .tint(.white)
        .task { rendered = Self.render(html) }
    }

    static func render(_ html: String) -> AttributedString {
        guard let data = html.data(using: .utf8),
              let ns = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              )
        else {
            return AttributedString(html)
        }
        var attributed = AttributedString(ns)
        // The HTML importer sets its own (dark) color/font; force overlay-appropriate styling.
        attributed.foregroundColor = .white
        attributed.font = .title3
        return attributed
    }
}
