import Foundation

struct TrackedApp: Codable, Identifiable {
    let bundleIdentifier: String
    let displayName: String
    var totalTimeUsed: TimeInterval
    var id: String { bundleIdentifier }

    init(bundleIdentifier: String, displayName: String, totalTimeUsed: TimeInterval = 0) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.totalTimeUsed = totalTimeUsed
    }
}
