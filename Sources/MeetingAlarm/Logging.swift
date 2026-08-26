import OSLog

/// One place to mint subsystem-scoped loggers. Golden rule: no `print` in `Sources/`.
enum Log {
    static let subsystem = "com.goanpeca.MeetingAlarm"

    static func make(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
