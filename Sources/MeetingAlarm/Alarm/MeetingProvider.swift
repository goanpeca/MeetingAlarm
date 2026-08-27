import SwiftUI

/// Maps a meeting URL's host to a Join-button label and brand accent color.
enum MeetingProvider {
    static func label(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom") {
            return "Join Zoom"
        }
        if host.contains("meet.google") {
            return "Join Meet"
        }
        if host.contains("teams") {
            return "Join Teams"
        }
        if host.contains("webex") {
            return "Join Webex"
        }
        if host.contains("whereby") {
            return "Join Whereby"
        }
        return "Join meeting"
    }

    static func color(for url: URL) -> Color {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom") {
            return Color(red: 0.18, green: 0.55, blue: 1.0)
        }
        if host.contains("meet.google") {
            return Color(red: 0.0, green: 0.51, blue: 0.18)
        }
        if host.contains("teams") {
            return Color(red: 0.35, green: 0.36, blue: 0.66)
        }
        if host.contains("webex") {
            return Color(red: 0.0, green: 0.44, blue: 0.55)
        }
        if host.contains("whereby") {
            return Color(red: 0.35, green: 0.34, blue: 0.84)
        }
        return .accentColor
    }
}
