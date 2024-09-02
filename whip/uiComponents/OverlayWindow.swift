import SwiftUI
import AppKit

class OverlayWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .hudWindow],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false

        let overlayView = NSHostingView(rootView: OverlayContentView())
        overlayView.frame = contentRect
        contentView = overlayView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
