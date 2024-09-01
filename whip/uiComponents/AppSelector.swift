import SwiftUI
import AppKit

struct AppSelector: NSViewRepresentable {
    @Binding var selection: AppInfo?
    let options: [AppInfo]

    func makeNSView(context: Context) -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        popUp.target = context.coordinator
        popUp.action = #selector(Coordinator.selectionChanged(_:))
        return popUp
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        nsView.removeAllItems()

        let defaultItem = NSMenuItem(title: "Select an app", action: nil, keyEquivalent: "")
        defaultItem.image = nil
        nsView.menu?.addItem(defaultItem)

        for option in options {
            let item = NSMenuItem(title: option.displayName, action: nil, keyEquivalent: "")
            if let icon = option.icon {
                item.image = icon.resized(to: NSSize(width: 16, height: 16))
            } else {
                item.image = NSImage(systemSymbolName: "app.square", accessibilityDescription: nil)?.resized(to: NSSize(width: 16, height: 16))
            }
            item.representedObject = option
            nsView.menu?.addItem(item)
        }

        if let selection = selection, let index = options.firstIndex(where: { $0.id == selection.id }) {
            nsView.selectItem(at: index + 1)
        } else {
            nsView.selectItem(at: 0)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: AppSelector

        init(_ parent: AppSelector) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if sender.indexOfSelectedItem == 0 {
                parent.selection = nil
            } else if let selectedItem = sender.selectedItem,
                      let selectedApp = selectedItem.representedObject as? AppInfo {
                parent.selection = selectedApp
            }
        }
    }
}
