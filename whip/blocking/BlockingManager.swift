import AppKit
import Combine
import OSLog

class BlockingManager: ObservableObject {
    private let logger = Logger(subsystem: "dev.fratta.whip", category: "BlockingManager")
    private weak var timeLimitSettings: TimeLimitSettings?
    private weak var usageTracker: UsageTracker?
    private var cancellables = Set<AnyCancellable>()

    private weak var overlayWindow: OverlayWindow?
    private var blockedApp: NSRunningApplication?
    private var workspaceNotificationObserver: Any?
    private var updateTimer: Timer?
    private let windowDelegate = OverlayWindowDelegate()

    deinit {
        cleanupResources()
    }

    func setDependencies(usageTracker: UsageTracker, timeLimitSettings: TimeLimitSettings) {
        self.usageTracker = usageTracker
        self.timeLimitSettings = timeLimitSettings
        setupEnforcement()
        setupWorkspaceObserver()
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
            guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppActivation(activatedApp)
        }
    }

    private func handleAppActivation(_ activatedApp: NSRunningApplication) {
        if activatedApp.bundleIdentifier != blockedApp?.bundleIdentifier {
            overlayWindow?.orderOut(nil)
        } else {
            overlayWindow?.orderFront(nil)
        }
    }

    private func checkAndEnforceTimeLimit(for event: AppUsageEvent) {
        guard let timeLimit = timeLimitSettings?.timeLimitRules[event.appId] else { return }

        let shouldBlock = isOutsideSchedule(timeLimit.schedule) ||
                          (timeLimit.dailyLimit != nil && event.secondsUsedToday >= timeLimit.dailyLimit!)

        if shouldBlock {
            enforceBlocking(for: event.runningApp)
        }
    }

    private func isOutsideSchedule(_ schedule: Schedule?) -> Bool {
        guard let schedule = schedule else { return false }

        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: schedule.start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: schedule.end)

        // Convert all times to minutes since midnight for easier comparison
        let nowMinutes = nowComponents.hour! * 60 + nowComponents.minute!
        let startMinutes = startComponents.hour! * 60 + startComponents.minute!
        let endMinutes = endComponents.hour! * 60 + endComponents.minute!

        if startMinutes < endMinutes {
            // Schedule does not cross midnight
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            // Schedule crosses midnight
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }

    private func enforceBlocking(for runningApp: NSRunningApplication) {
        guard let bundleID = runningApp.bundleIdentifier else {
            logger.warning("Failed to retrieve bundle identifier for running app.")
            return
        }

        guard runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            logger.warning("Attempting to block our own app, skipping")
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

    private func updateOverlayPosition(_ overlay: OverlayWindow, to frame: NSRect) {
        if frame != overlay.frame {
            overlay.setFrame(frame, display: true)
        }
        overlay.orderFront(nil)
    }

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition()
        }
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

    private func getMainWindowInfo(for app: NSRunningApplication) -> (windowNumber: Int, frame: NSRect)? {
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == app.processIdentifier,
                  let windowNumber = windowInfo[kCGWindowNumber as String] as? Int,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }

            let frame = NSRect(x: bounds["X"] ?? 0,
                               y: bounds["Y"] ?? 0,
                               width: bounds["Width"] ?? 0,
                               height: bounds["Height"] ?? 0)

            return (windowNumber, frame)
        }

        return nil
    }

    private func convertToScreenCoordinates(_ rect: NSRect) -> NSRect {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSRect(x: rect.minX,
                      y: screenFrame.height - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }
}

class OverlayWindowDelegate: NSObject, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onWindowClose?()
    }
}
