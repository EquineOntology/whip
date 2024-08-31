import SwiftUI

@main
struct Main: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
