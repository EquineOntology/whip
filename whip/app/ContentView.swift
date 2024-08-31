import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            UsageStatisticsView()
                .tabItem {
                    Label("Usage", systemImage: "chart.bar")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .padding()
        .frame(width: 800, height: 600)
    }
}
