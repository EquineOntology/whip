import Foundation

class TimeLimitSettings: ObservableObject {
    @Published var timeLimitRules: [String: TimeInterval] = [:]
    @Published var timeLimitInputs: [String: String] = [:]

    init() {
        loadTimeLimits()
    }

    func addApp(_ appInfo: AppInfo) {
        if !timeLimitRules.keys.contains(appInfo.id) {
            timeLimitRules[appInfo.id] = 0 // Default to no limit
            timeLimitInputs[appInfo.id] = "0"
        }
    }

    func removeApp(_ appInfo: AppInfo) {
        timeLimitRules.removeValue(forKey: appInfo.id)
        timeLimitInputs.removeValue(forKey: appInfo.id)
        objectWillChange.send()
    }

    func setTimeLimit(for appInfo: AppInfo, seconds: TimeInterval) {
        timeLimitRules[appInfo.id] = seconds
        timeLimitInputs[appInfo.id] = String(format: "%.0f", seconds)
    }

    func updateRules(_ newRules: [String: TimeInterval]) {
        timeLimitRules = newRules
        loadTimeLimits()
    }

    private func loadTimeLimits() {
        for (appId, timeInterval) in timeLimitRules {
            timeLimitInputs[appId] = String(format: "%.0f", timeInterval)
        }
    }
}
