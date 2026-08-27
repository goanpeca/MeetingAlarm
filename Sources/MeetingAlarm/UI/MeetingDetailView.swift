import SwiftUI

/// The expandable detail under a meeting row: who's invited and the full description.
/// Uses system (secondary) colors so it follows the light/dark theme.
struct MeetingDetailView: View {
    let meeting: Meeting

    @State private var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

    private func loadDescription() {
        guard let notes = meeting.notes, !notes.isEmpty else { return }
        description = HTMLText.plain(notes)
    }
}
