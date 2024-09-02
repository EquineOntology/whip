import AppKit

class OverlayWindowDelegate: NSObject, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onWindowClose?()
    }
}
