import SwiftUI

struct AppUsage: Identifiable, Equatable {
    let appInfo: AppInfo
    let timeSpent: TimeInterval
    let runningApp: NSRunningApplication?
    var id: String { appInfo.id }
}
