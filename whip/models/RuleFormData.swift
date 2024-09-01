import Foundation

struct RuleFormData {
    var app: AppInfo?
    var ruleType: RuleType
    var timeLimit: String = ""
    var startTime: Date
    var endTime: Date
    
    init(app: AppInfo? = nil, type: RuleType = .limit, limit: TimeLimit? = nil) {
        self.app = app
        self.ruleType = type

        let calendar = Calendar.current

        if let limit = limit {
            self.timeLimit = limit.dailyLimit.map { TimeUtils.formatTimeInterval($0) } ?? "1h"
            self.startTime = limit.schedule?.start ?? calendar.date(from: DateComponents(hour: 23, minute: 0))!
            self.endTime = limit.schedule?.end ?? calendar.date(from: DateComponents(hour: 5, minute: 0))!
        } else {
            // Sane defaults for new rules
            self.timeLimit = "1h"
            self.startTime = calendar.date(from: DateComponents(hour: 23, minute: 0))!
            self.endTime = calendar.date(from: DateComponents(hour: 5, minute: 0))!
        }
    }
}
