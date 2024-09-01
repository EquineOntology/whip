import AppKit
import Combine
import OSLog

class BlockingService: ObservableObject {
    private let logger = Logger(subsystem: "dev.fratta.whip", category: "BlockingService")
    private weak var ruleService: RuleService?
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

    func setDependencies(usageTracker: UsageTracker, ruleService: RuleService) {
        self.usageTracker = usageTracker
        self.ruleService = ruleService
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
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition()
        }
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
