import Foundation

struct Schedule: Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    func shouldBlock(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        // hour*60 used to calculate minutes since midnight.
        let currentMinutes = components.hour! * 60 + components.minute!
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    func toString() -> String {
        let startTime = String(format: "%02d:%02d", startHour, startMinute)
        let endTime = String(format: "%02d:%02d", endHour, endMinute)
        return "\(startTime) - \(endTime)"
    }

    func overlaps(with other: Schedule) -> Bool {
        let start1 = startHour * 60 + startMinute
        let end1 = endHour * 60 + endMinute
        let start2 = other.startHour * 60 + other.startMinute
        let end2 = other.endHour * 60 + other.endMinute

        if start1 < end1 && start2 < end2 {
            return start1 < end2 && start2 < end1
        } else if start1 >= end1 && start2 >= end2 {
            return true
        } else if start1 >= end1 {
            return start2 < end1 || start1 < end2
        } else {
            return start1 < end2 || start2 < end1
        }
    }
}
