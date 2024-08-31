import SwiftUI

struct AppUsage: Identifiable, Equatable {
    let appInfo: AppInfo
    let timeSpent: TimeInterval
    var id: String { appInfo.id }
    
    static func == (lhs: AppUsage, rhs: AppUsage) -> Bool {
        lhs.appInfo == rhs.appInfo && lhs.timeSpent == rhs.timeSpent
    }
}
