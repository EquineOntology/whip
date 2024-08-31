import SwiftData
import OSLog

@MainActor
class StatisticsManager: ObservableObject {
    @Published private var dailyUsage: [String: [String: TimeInterval]] = [:]
    private let logger = Logger(subsystem: "dev.fratta.whip.UsageTracker", category: "StatisticsManager")

    func updateUsage(appInfo: AppInfo, website: String?, duration: TimeInterval) {
        let dateKey = TimeUtils.currentDateAsString()
        let key = website ?? appInfo.id

        dailyUsage[dateKey, default: [:]][key, default: 0] += duration
    }
}
