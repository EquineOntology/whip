import Foundation

struct TimeLimit: Codable {
    var dailyLimit: TimeInterval?
    var schedule: Schedule?

    func shouldBlock(at date: Date, usedTime: TimeInterval) -> Bool {
        if let schedule = schedule, schedule.shouldBlock(date) {
            return true
        }
        if let dailyLimit = dailyLimit, usedTime >= dailyLimit {
            return true
        }
        return false
    }
}
