import Foundation

/// Deterministic flatten + sort of per-account meeting lists. Duplicates across
/// accounts are kept (each is a distinct row); ordering is by start then id so the
/// list is stable regardless of account fetch order.
enum MeetingMerge {
    static func merged(_ groups: [[Meeting]]) -> [Meeting] {
        groups.flatMap(\.self).sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
    }
}
