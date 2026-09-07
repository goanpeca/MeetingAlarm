import AppKit
import SwiftUI

/// The expandable detail under a meeting row: the join link(s) first, then who's invited and
/// the full description. Uses system (secondary) colors so it follows the light/dark theme.
struct MeetingDetailView: View {
    let meeting: Meeting

    @State private var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !meeting.joinURLs.isEmpty {
                joinButtons
            }
            if !meeting.attendees.isEmpty {
                Label(meeting.attendees.joined(separator: ", "), systemImage: "person.2")
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let description, !description.isEmpty {
                ScrollView {
                    Text(description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 120)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .task { loadDescription() }
    }

    /// One brand-tinted button per detected provider that opens the link in the browser/app.
    private var joinButtons: some View {
        HStack(spacing: 8) {
            ForEach(meeting.joinURLs, id: \.self) { url in
                Button {
                    openLink(url)
                } label: {
                    Label(MeetingProvider.label(for: url), systemImage: "video.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(MeetingProvider.color(for: url))
                .accessibilityHint("Opens the meeting link")
            }
        }
        .padding(.bottom, 2)
    }

    /// Open a detected link, re-checking the scheme at the sink — `joinURLs` is already web-only,
    /// but never hand a non-http(s) URL from calendar data to `NSWorkspace`.
    private func openLink(_ url: URL) {
        guard MeetingLink.isWebURL(url) else { return }
        NSWorkspace.shared.open(url)
    }

    private func loadDescription() {
        guard let notes = meeting.notes, !notes.isEmpty else { return }
        description = HTMLText.plain(notes)
    }
}
