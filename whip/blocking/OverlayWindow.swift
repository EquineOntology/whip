import SwiftUI
import AppKit

class OverlayWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .hudWindow],
                   backing: .buffered,
                   defer: false)

        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false

        let overlayView = NSHostingView(rootView: OverlayContentView())
        overlayView.frame = contentRect
        self.contentView = overlayView
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}
