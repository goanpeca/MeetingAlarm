import Foundation

/// A selectable calendar the user can show or hide in the day list.
struct CalendarInfo: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    /// Owning source/account (e.g. an iCloud/Google account name), for grouping.
    let sourceTitle: String
}
