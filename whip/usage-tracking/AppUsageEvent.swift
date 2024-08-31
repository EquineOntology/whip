import AppKit

struct AppUsageEvent {
    let appId: String
    let runningApp: NSRunningApplication
    let secondsUsedToday: TimeInterval
}
