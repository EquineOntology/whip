import Foundation

enum TimeUtils {
    static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
    }

    static func dateAsString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date)
    }

    static func dateFromString(_ input: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: input)
    }

    static func IntervalFromDurationString(_ input: String) -> TimeInterval? {
        let pattern = #"(\d+)\s*([hms])"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex?.matches(in: input, options: [], range: nsRange) ?? []

        var totalSeconds: TimeInterval = 0

        for match in matches {
            guard let valueRange = Range(match.range(at: 1), in: input),
                  let unitRange = Range(match.range(at: 2), in: input),
                  let value = Double(input[valueRange]) else {
                continue
            }

            let unit = input[unitRange].lowercased()

            switch unit {
            case "h": totalSeconds += value * 3600
            case "m": totalSeconds += value * 60
            case "s": totalSeconds += value
            default: return nil
            }
        }

        return totalSeconds > 0 ? totalSeconds : nil
    }
}
