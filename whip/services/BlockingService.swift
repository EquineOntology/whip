import AppKit
import Combine
import OSLog

@MainActor
class BlockingService: ObservableObject {
    private let logger = Logger(subsystem: "dev.fratta.whip", category: "BlockingService")
    private weak var ruleService: RuleService?
    private weak var usageTracker: UsageTracker?
    private weak var notificationService: NotificationService?
    private var cancellables = Set<AnyCancellable>()
    private var isCleanedUp = false
    private var updateTask: Task<Void, Never>?
    private var notificationTask: Task<Void, Never>?

    private weak var overlayWindow: OverlayWindow?
    private var blockedApp: NSRunningApplication?
    private var workspaceNotificationObserver: Any?
    private var updateTimer: Timer?
    private let windowDelegate = OverlayWindowDelegate()
    private var upcomingBlockTimes: [String: Date] = [:]

    func setDependencies(usageTracker: UsageTracker, ruleService: RuleService, notificationService: NotificationService) {
        self.usageTracker = usageTracker
        self.ruleService = ruleService
        self.notificationService = notificationService
        setupEnforcement()
        setupWorkspaceObserver()
        setupNotifications()
    }

    private func setupEnforcement() {
        usageTracker?.usageUpdated
            .sink { [weak self] event in
                self?.checkAndEnforceTimeLimit(for: event)
            }
            .store(in: &cancellables)
    }

    private func setupWorkspaceObserver() {
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let bundleIdentifier = activatedApp.bundleIdentifier ?? ""
            Task { @MainActor in
                self.handleAppActivation(bundleIdentifier: bundleIdentifier)
            }
        }
    }

    private func handleAppActivation(bundleIdentifier: String) {
        if bundleIdentifier != blockedApp?.bundleIdentifier {
            overlayWindow?.orderOut(nil)
        } else {
            overlayWindow?.orderFront(nil)
        }
    }

    private func setupNotifications() {
        notificationTask?.cancel()
        notificationTask = Task {
            while !Task.isCancelled {
                checkAndScheduleNotifications()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func checkAndScheduleNotifications() {
        let currentDate = Date()
        let currentUsage = usageTracker?.getCurrentDayUsage() ?? [:]

        var upcomingBlocks: [String: Date] = [:]

        for (appId, _) in ruleService?.timeLimitRules ?? [:] {
            if let nextBlockTime = ruleService?.getUpcomingBlockTimes(for: appId, currentUsage: currentUsage[appId] ?? 0, currentDate: currentDate).first {
                upcomingBlocks[appId] = nextBlockTime
            }
        }

        let newBlockTimes = upcomingBlocks.filter { $0.value != upcomingBlockTimes[$0.key] }
        upcomingBlockTimes = upcomingBlocks

        notificationService?.cancelAllNotifications()

        let notificationIntervals = [1800.0, 600.0, 60.0] // 30 minutes, 10 minutes, 1 minute

        for (blockTime, apps) in groupNotifications(newBlockTimes) {
            let appNames = apps.compactMap { usageTracker?.getAppInfo(forBundleIdentifier: $0).displayName }
            let title = "Upcoming App Limit"

            for interval in notificationIntervals {
                let notificationDate = blockTime.addingTimeInterval(-interval)
                if notificationDate > currentDate {
                    let timeUntilBlock = blockTime.timeIntervalSince(notificationDate)
                    let body = "\(appNames.joined(separator: ", ")) will be blocked in \(TimeUtils.formatTimeIntervalForNotification(timeUntilBlock))"
                    notificationService?.scheduleNotification(title: title, body: body, date: notificationDate)
                }
            }
        }
    }

    private func groupNotifications(_ blockTimes: [String: Date]) -> [Date: [String]] {
        var grouped: [Date: [String]] = [:]

        for (appId, date) in blockTimes {
            grouped[date, default: []].append(appId)
        }

        return grouped
    }

    private func handleAppActivation(_ activatedApp: NSRunningApplication) {
        if activatedApp.bundleIdentifier != blockedApp?.bundleIdentifier {
            overlayWindow?.orderOut(nil)
        } else {
            overlayWindow?.orderFront(nil)
        }
    }

    private func checkAndEnforceTimeLimit(for appUsage: AppUsage) {
        guard let timeLimit = ruleService?.timeLimitRules[appUsage.appInfo.id] else { return }

        let now = Date()
        let shouldBlock = timeLimit.shouldBlock(at: now, usedTime: appUsage.timeSpent)

        if shouldBlock, let runningApp = appUsage.runningApp {
            enforceBlocking(for: runningApp)
        }
    }

    private func enforceBlocking(for runningApp: NSRunningApplication) {
        guard let bundleID = runningApp.bundleIdentifier,
              runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            logger.warning("Invalid app for blocking")
            return
        }

        blockedApp = runningApp
        logger.info("Attempting to block app: \(runningApp.localizedName ?? bundleID) (PID: \(runningApp.processIdentifier))")

        updateOrCreateOverlay(for: runningApp)
    }

    private func updateOrCreateOverlay(for runningApp: NSRunningApplication) {
        if let windowInfo = getMainWindowInfo(for: runningApp) {
            let screenFrame = convertToScreenCoordinates(windowInfo.frame)
            if let overlay = overlayWindow {
                updateOverlayPosition(overlay, to: screenFrame)
            } else {
                createOverlay(at: screenFrame)
            }
        } else {
            overlayWindow?.orderOut(nil)
        }
    }

    private func createOverlay(at frame: NSRect) {
        let overlayWindow = OverlayWindow(contentRect: frame)
        overlayWindow.delegate = windowDelegate
        windowDelegate.onWindowClose = { [weak self] in
            self?.cleanupOverlay()
        }
        overlayWindow.makeKeyAndOrderFront(nil)
        self.overlayWindow = overlayWindow

        startPeriodicUpdates()
    }

    private func startPeriodicUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateOverlayPosition()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    private func stopPeriodicUpdates() {
        updateTask?.cancel()
        updateTask = nil
    }

    private func updateOverlayPosition(_ overlay: OverlayWindow, to frame: NSRect) {
        if frame != overlay.frame {
            overlay.setFrame(frame, display: true)
        }
        overlay.orderFront(nil)
    }

    private func updateOverlayPosition() {
        guard let runningApp = blockedApp,
              let windowInfo = getMainWindowInfo(for: runningApp),
              let overlay = overlayWindow else {
            return
        }

        let screenFrame = convertToScreenCoordinates(windowInfo.frame)
        updateOverlayPosition(overlay, to: screenFrame)

        if runningApp.isTerminated {
            logger.info("Blocked app terminated. Cleaning up overlay.")
            cleanupOverlay()
        } else if runningApp == NSWorkspace.shared.frontmostApplication {
            overlay.orderFront(nil)
        } else {
            overlay.orderOut(nil)
        }
    }

    private func cleanupOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        blockedApp = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func cleanupResources() {
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        cleanupOverlay()
        cancellables.removeAll()
    }

    func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true

        notificationTask?.cancel()
        if let observer = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        updateTask?.cancel()
        overlayWindow?.close()
        overlayWindow = nil
        blockedApp = nil
        cancellables.removeAll()
    }

    private func getMainWindowInfo(for app: NSRunningApplication) -> (windowNumber: Int, frame: NSRect)? {
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        return windowList.first { windowInfo in
            (windowInfo[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier
        }.flatMap { windowInfo in
            guard let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"] else {
                return nil
            }
            let frame = NSRect(x: x, y: y, width: width, height: height)
            return (windowNumber, frame)
        }
    }

    private func convertToScreenCoordinates(_ rect: NSRect) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSRect(x: rect.minX,
                      y: screenFrame.height - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }
}
