import SwiftUI

@main
struct Main: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UserDefaults.standard.set(true, forKey: "NSApplicationHasUIElement")
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
