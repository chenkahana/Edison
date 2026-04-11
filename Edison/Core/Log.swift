import OSLog

enum Log {
    static let capture     = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "capture")
    static let store       = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "store")
    static let shortcuts   = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "shortcuts")
    static let clipboard   = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "clipboard")
    static let permissions = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "permissions")
}
