import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var hostingView: NSHostingView<AnyView>?
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        let contentView = AnyView(ContentView().environmentObject(appState!))
        hostingView = NSHostingView(rootView: contentView)
        hostingView?.frame = NSRect(x: 0, y: 0, width: 600, height: 470)

        statusBarController = StatusBarController(appState: appState!)
        statusBarController?.setContentView(hostingView!)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.performCleanup()
        appState?.notificationService.cancelAllNotifications()
    }
}
