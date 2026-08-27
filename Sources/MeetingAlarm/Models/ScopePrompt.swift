import Foundation

/// A pending "this event / all in the series" question for a recurring meeting, shown as an
/// in-popover overlay (a system `confirmationDialog` can't be clicked inside a menu-bar
/// window).
struct ScopePrompt: Identifiable, Equatable {
    enum Kind: Equatable { case arm, disarm }
    let meeting: Meeting
    let kind: Kind
    var id: String {
        "\(meeting.id):\(kind == .arm ? "arm" : "disarm")"
    }
}
