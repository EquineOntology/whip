import SwiftUI
import Combine
import OSLog

@MainActor
class UsageTracker: ObservableObject {
    @Published private(set) var currentApp: AppInfo?
    @Published private(set) var usageByApp: [String: TimeInterval] = [:]

    let usageUpdated = PassthroughSubject<AppUsageEvent, Never>()
    var cancellables = Set<AnyCancellable>()

    private let logger = Logger(subsystem: "dev.fratta.whip", category: "UsageTracker")

    private weak var statisticsManager: StatisticsManager?

    private var currentRunningApp: NSRunningApplication?
    private var startTime: Date?
    private let updateFrequency: TimeInterval = 1
    
    private var excludedAppIds: Set<String> = ["dev.fratta.whip"]

    func setStatisticsManager(_ manager: StatisticsManager) {
        self.statisticsManager = manager
    }

    func startTracking() {
        observeAppChanges()
        startUpdateTimer()
    }

    func stopTracking() {
        cancellables.removeAll()
        updateUsage(app: currentApp)
    }

    private func observeAppChanges() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.activeAppDidChange(app)
            }
            .store(in: &cancellables)
    }

    private func startUpdateTimer() {
        Timer.publish(every: updateFrequency, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentAppUsage()
            }
            .store(in: &cancellables)
    }

    private func updateCurrentAppUsage() {
        guard let currentApp = currentApp else { return }
        updateUsage(app: currentApp)
        startTime = Date()
    }

    private func activeAppDidChange(_ app: NSRunningApplication) {
        let newAppInfo = AppInfoManager.shared.getAppInfo(forRunningApplication: app)
        logger.debug("New frontmost app: \(newAppInfo.displayName)")

        updateUsage(app: currentApp)

        // Only update currentApp and start tracking if the new app is not excluded
        if !excludedAppIds.contains(newAppInfo.id) {
            currentApp = newAppInfo
            currentRunningApp = app
            startTime = Date()
        } else {
            currentApp = nil
            currentRunningApp = nil
            startTime = nil
        }
    }

    private func updateUsage(app: AppInfo?) {
        guard let app = app,
              let start = startTime,
              let runningApp = currentRunningApp,
              !excludedAppIds.contains(app.id) else { return }

        let timeSpent = Date().timeIntervalSince(start)
        usageByApp[app.id, default: 0] += timeSpent
        statisticsManager?.updateUsage(appInfo: app, website: nil, duration: timeSpent)

        let totalUsageToday = usageByApp[app.id] ?? 0
        usageUpdated.send(AppUsageEvent(
            appId: app.id,
            runningApp: runningApp,
            secondsUsedToday: totalUsageToday
        ))

        objectWillChange.send()
    }

    func getSortedUsageData() -> [AppUsage] {
        usageByApp.map {
            let appInfo = AppInfoManager.shared.getAppInfo(forBundleIdentifier: $0.key)
            return AppUsage(appInfo: appInfo, timeSpent: $0.value)
        }
        .sorted { $0.timeSpent > $1.timeSpent }
    }

    func getAllUsageData() -> [String: TimeInterval] {
        return usageByApp
    }

    func setInitialUsageData(_ data: [String: TimeInterval]) {
        usageByApp = data.filter { !excludedAppIds.contains($0.key) }
        logger.debug("Set initial usage data: \(self.usageByApp)")
    }

    func resetDailyUsage() {
        usageByApp.removeAll()
    }
}
