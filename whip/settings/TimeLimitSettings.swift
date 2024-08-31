import Foundation

struct TimeLimit: Codable {
    var dailyLimit: TimeInterval?
    var schedule: Schedule?
    
    func debugDescription() -> String {
        return "Daily Limit: \(dailyLimit?.description ?? "nil"), Schedule: \(schedule?.debugDescription() ?? "nil")"
    }
}

struct Schedule: Codable {
    var start: Date
    var end: Date
    
    func debugDescription() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Start: \(formatter.string(from: start)), End: \(formatter.string(from: end))"
    }
}

class TimeLimitSettings: ObservableObject {
    @Published var timeLimitRules: [String: TimeLimit] = [:]
    @Published var timeLimitInputs: [String: String] = [:]
    @Published var scheduleInputs: [String: (Date, Date)] = [:]

    func addApp(_ appInfo: AppInfo) {
        if !timeLimitRules.keys.contains(appInfo.id) {
            timeLimitRules[appInfo.id] = TimeLimit(dailyLimit: nil, schedule: nil)
            timeLimitInputs[appInfo.id] = ""
        }
    }

    func removeApp(_ appInfo: AppInfo) {
        timeLimitRules.removeValue(forKey: appInfo.id)
        timeLimitInputs.removeValue(forKey: appInfo.id)
        objectWillChange.send()
    }

    func setTimeLimit(for appInfo: AppInfo, seconds: TimeInterval?) {
        if timeLimitRules[appInfo.id] == nil {
            timeLimitRules[appInfo.id] = TimeLimit()
        }
        timeLimitRules[appInfo.id]?.dailyLimit = seconds
        timeLimitInputs[appInfo.id] = seconds != nil ? String(format: "%.0f", seconds!) : ""
    }

    func setSchedule(for appInfo: AppInfo, schedule: Schedule) {
        if timeLimitRules[appInfo.id] == nil {
            timeLimitRules[appInfo.id] = TimeLimit()
        }
        timeLimitRules[appInfo.id]?.schedule = schedule
        scheduleInputs[appInfo.id] = (start: schedule.start, end: schedule.end)
        print("Set schedule for \(appInfo.id): \(timeLimitRules[appInfo.id]?.debugDescription() ?? "nil")")
    }

    func clearTimeLimit(for appInfo: AppInfo) {
        timeLimitRules[appInfo.id]?.dailyLimit = nil
        timeLimitInputs[appInfo.id] = ""
    }

    func clearSchedule(for appInfo: AppInfo) {
        timeLimitRules[appInfo.id]?.schedule = nil
    }

    func updateRules(_ newRules: [String: TimeLimit]) {
        timeLimitRules = newRules
        for (appId, limit) in newRules {
            if let dailyLimit = limit.dailyLimit {
                timeLimitInputs[appId] = String(format: "%.0f", dailyLimit)
            } else {
                timeLimitInputs[appId] = ""
            }
            
            if let schedule = limit.schedule {
                scheduleInputs[appId] = (schedule.start, schedule.end)
            } else {
                scheduleInputs[appId] = nil
            }
        }
        objectWillChange.send()
    }

    func updateSchedule(for appInfo: AppInfo, schedule: Schedule) {
        if timeLimitRules[appInfo.id] == nil {
            timeLimitRules[appInfo.id] = TimeLimit()
        }
        if timeLimitRules[appInfo.id]?.schedule == nil {
            timeLimitRules[appInfo.id]?.schedule = schedule
        } else {
            timeLimitRules[appInfo.id]?.schedule?.start = schedule.start
            timeLimitRules[appInfo.id]?.schedule?.end = schedule.end
        }
        scheduleInputs[appInfo.id] = (start: schedule.start, end: schedule.end)
        objectWillChange.send()
    }

    func getSchedule(for appInfo: AppInfo) -> Schedule? {
        return timeLimitRules[appInfo.id]?.schedule
    }

    func updateTimeLimit(for appInfo: AppInfo, seconds: TimeInterval?, schedule: Schedule?) {
        if timeLimitRules[appInfo.id] == nil {
            timeLimitRules[appInfo.id] = TimeLimit()
        }
        timeLimitRules[appInfo.id]?.dailyLimit = seconds
        timeLimitRules[appInfo.id]?.schedule = schedule
        timeLimitInputs[appInfo.id] = seconds != nil ? String(format: "%.0f", seconds!) : ""
        if let schedule = schedule {
            scheduleInputs[appInfo.id] = (start: schedule.start, end: schedule.end)
        } else {
            scheduleInputs[appInfo.id] = nil
        }
        objectWillChange.send()
    }

    func getTimeLimit(for appInfo: AppInfo) -> TimeLimit? {
        return timeLimitRules[appInfo.id]
    }
}
