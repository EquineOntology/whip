import SwiftUI
import Combine
import OSLog

@MainActor
class UsageTracker: ObservableObject {
    @Published private(set) var currentApp: AppInfo?
    @Published private(set) var usageByApp: [String: TimeInterval] = [:]

    let usageUpdated = PassthroughSubject<AppUsage, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "dev.fratta.whip", category: "UsageTracker")
    private var currentRunningApp: NSRunningApplication?
    private var startTime: Date?
    private let updateFrequency: TimeInterval = 1
    private let excludedAppIds: Set<String> = ["dev.fratta.whip", "com.apple.loginwindow"]

    init() {
        setupObservers()
    }

    func startTracking() {
        startUpdateTimer()
    }

    func stopTracking() {
        cancellables.removeAll()
        updateUsage(app: currentApp)
    }

    func getCurrentDayUsage() -> [String: TimeInterval] {
        return usageByApp
    }

    func getSortedUsageData() -> [AppUsage] {
        usageByApp.map { (bundleId, timeSpent) in
            let appInfo = getAppInfo(forBundleIdentifier: bundleId)
            return AppUsage(appInfo: appInfo, timeSpent: timeSpent, runningApp: nil)
        }
        .sorted { $0.timeSpent > $1.timeSpent }
    }

    func setInitialUsageData(_ data: [String: TimeInterval]) {
        usageByApp = data.filter { !excludedAppIds.contains($0.key) }
        logger.debug("Set initial usage data: \(self.usageByApp)")
    }

    func resetDailyUsage() {
        usageByApp.removeAll()
    }

    private func setupObservers() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] in self?.activeAppDidChange($0) }
            .store(in: &cancellables)
    }

    private func startUpdateTimer() {
        Timer.publish(every: updateFrequency, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateCurrentAppUsage() }
            .store(in: &cancellables)
    }

    private func updateCurrentAppUsage() {
        guard let currentApp = currentApp else { return }
        updateUsage(app: currentApp)
        startTime = Date()
    }

    private func activeAppDidChange(_ app: NSRunningApplication) {
        let newAppInfo = getAppInfo(forRunningApplication: app)
        logger.debug("New frontmost app: \(newAppInfo.displayName)")

        updateUsage(app: currentApp)

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

    private func getAppInfo(forRunningApplication app: NSRunningApplication) -> AppInfo {
        let bundleIdentifier = app.bundleIdentifier ?? "unknown"
        let displayName = app.localizedName ?? bundleIdentifier
        return AppInfo(id: bundleIdentifier, displayName: displayName)
    }

    private func getAppInfo(forBundleIdentifier bundleId: String) -> AppInfo {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            return getAppInfo(forRunningApplication: runningApp)
        } else {
            // Fallback for apps that are not currently running
            let displayName = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.lastPathComponent ?? bundleId
            return AppInfo(id: bundleId, displayName: displayName)
        }
    }

    private func updateUsage(app: AppInfo?) {
        guard let app = app,
              let start = startTime,
              let runningApp = currentRunningApp,
              !excludedAppIds.contains(app.id) else { return }

        let timeSpent = Date().timeIntervalSince(start)
        usageByApp[app.id, default: 0] += timeSpent

        let totalUsageToday = usageByApp[app.id] ?? 0
        usageUpdated.send(AppUsage(appInfo: app, timeSpent: totalUsageToday, runningApp: runningApp))

        objectWillChange.send()
    }
}
