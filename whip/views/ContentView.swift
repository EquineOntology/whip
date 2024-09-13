import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            TabView(selection: $selectedTab) {
                UsageStatisticsView(
                    viewModel: UsageStatisticsViewModel(
                        usageTracker: appState.usageTracker,
                        historicalUsageService: appState.historicalUsageService,
                        appInfoProvider: appState.appInfoProvider
                    )
                )
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
            
            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .foregroundColor(.white)
            }
        }.padding()
    }
}
