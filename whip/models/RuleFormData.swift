import Foundation

struct RuleFormData {
    var app: AppInfo?
    var ruleType: RuleType
    var timeLimit: String = ""
    var scheduleStartHour: Int = 0
    var scheduleStartMinute: Int = 0
    var scheduleEndHour: Int = 0
    var scheduleEndMinute: Int = 0
    
    init(app: AppInfo? = nil, type: RuleType = .limit, limit: TimeLimit? = nil) {
        self.app = app
        self.ruleType = type

        if let limit = limit {
            self.timeLimit = limit.dailyLimit.map { TimeUtils.formatTimeInterval($0) } ?? "1h"
            if let schedule = limit.schedule {
                self.scheduleStartHour = schedule.startHour
                self.scheduleStartMinute = schedule.startMinute
                self.scheduleEndHour = schedule.endHour
                self.scheduleEndMinute = schedule.endMinute
            } else {
                // Default schedule if none exists
                self.scheduleStartHour = 23
                self.scheduleStartMinute = 0
                self.scheduleEndHour = 5
                self.scheduleEndMinute = 0
            }
        } else {
            // Sane defaults for new rules
            self.timeLimit = "1h"
            self.scheduleStartHour = 23
            self.scheduleStartMinute = 0
            self.scheduleEndHour = 5
            self.scheduleEndMinute = 0
        }
    }
}
