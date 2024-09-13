import SwiftUI

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?
    private var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 600, height: 470)
        popover.behavior = .transient

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover()
            }
        }

        if let statusBarButton = statusItem.button {
            statusBarButton.image = self.getStatusBarIcon()
            statusBarButton.image?.size = NSSize(width: 18, height: 18)
            statusBarButton.image?.isTemplate = false
            statusBarButton.target = self
            statusBarButton.action = #selector(togglePopover(_:))
        }
    }

    private func getStatusBarIcon() -> NSImage? {
        if let image = NSImage(named: "AppIcon") {
            if let resizedImage = ImageUtils.resizeImage(image, to: NSSize(width: 18, height: 18)) {
                return resizedImage
            }
        }
        // Fallback to a system icon if the app icon is not found or can't be resized
        return NSImage(systemSymbolName: "timer", accessibilityDescription: "App Icon")
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        if let statusBarButton = statusItem.button {
            NotificationCenter.default.post(name: NSPopover.willShowNotification, object: popover)
            popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    func setContentView(_ view: NSView) {
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = view
    }
}
