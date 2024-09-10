import OSLog

class RuleService: ObservableObject {
    @Published private(set) var timeLimitRules: [String: TimeLimit] = [:]
    private let persistenceManager: PersistenceManaging

    private let logger = Logger(subsystem: "dev.fratta.whip", category: "RuleService")

    init(persistenceManager: PersistenceManaging) {
        self.persistenceManager = persistenceManager
        loadRules()
    }

    private func loadRules() {
        do {
            timeLimitRules = try persistenceManager.loadTimeLimitRules()
        } catch {
            logger.error("Failed to load time limit rules: \(error.localizedDescription)")
        }
    }

    private func saveRules() {
        do {
            try persistenceManager.saveTimeLimitRules(timeLimitRules)
        } catch {
            logger.error("Failed to save time limit rules: \(error.localizedDescription)")
        }
    }

    func updateRules(_ newRules: [String: TimeLimit]) {
        timeLimitRules = newRules
        saveRules()
    }

    func setTimeLimit(for appInfo: AppInfo, seconds: TimeInterval) {
        timeLimitRules[appInfo.id, default: TimeLimit()].dailyLimit = seconds
        saveRules()
    }

    func clearTimeLimit(for appInfo: AppInfo) {
        timeLimitRules[appInfo.id]?.dailyLimit = nil
        if timeLimitRules[appInfo.id]?.schedule == nil {
            timeLimitRules.removeValue(forKey: appInfo.id)
        }
        saveRules()
    }

    func setSchedule(for appInfo: AppInfo, schedule: Schedule) {
         timeLimitRules[appInfo.id, default: TimeLimit()].schedule = schedule
         saveRules()
     }

    func clearSchedule(for appInfo: AppInfo) {
        timeLimitRules[appInfo.id]?.schedule = nil
        if timeLimitRules[appInfo.id]?.dailyLimit == nil {
            timeLimitRules.removeValue(forKey: appInfo.id)
        }
        saveRules()
    }

    func getUpcomingBlockTimes(for appId: String, currentUsage: TimeInterval, currentDate: Date) -> [Date] {
        guard let rule = timeLimitRules[appId] else { return [] }

        var blockTimes: [Date] = []

        if let dailyLimit = rule.dailyLimit {
            let remainingTime = dailyLimit - currentUsage
            if remainingTime > 0 {
                blockTimes.append(currentDate.addingTimeInterval(remainingTime))
            }
        }

        if let schedule = rule.schedule {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentDate)
            components.hour = schedule.startHour
            components.minute = schedule.startMinute
            if let scheduleStart = calendar.date(from: components) {
                if scheduleStart > currentDate {
                    blockTimes.append(scheduleStart)
                } else {
                    components.day! += 1
                    if let nextDayStart = calendar.date(from: components) {
                        blockTimes.append(nextDayStart)
                    }
                }
            }
        }

        return blockTimes.sorted()
    }
}
