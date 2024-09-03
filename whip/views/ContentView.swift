import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            UsageStatisticsView(viewModel: UsageStatisticsViewModel(usageTracker: appState.usageTracker))
                .tabItem {
                    Label("Usage", systemImage: "chart.bar")
                }
                .tag(0)

            SettingsView(viewModel: SettingsViewModel(ruleService: appState.ruleService))
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .padding()
    }
}
