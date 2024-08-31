import AppKit

struct BlockingRule {
    let schedule: DateInterval?
    let timeLimit: TimeInterval?

    func isBlocked(at date: Date) -> Bool {
        if let schedule = schedule, !schedule.contains(date) {
            return true
        }
        return false
    }
}
