import Foundation

struct Schedule: Codable {
    var start: Date
    var end: Date

    func shouldBlock(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = components.hour! * 60 + components.minute!

        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        let startMinutes = startComponents.hour! * 60 + startComponents.minute!
        let endMinutes = endComponents.hour! * 60 + endComponents.minute!

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    func toString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
}
