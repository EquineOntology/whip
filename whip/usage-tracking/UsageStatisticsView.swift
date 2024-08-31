import SwiftUI
import Charts

struct UsageStatisticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var viewMode: ViewMode = .table
    @State private var usageData: [AppUsage] = []
    private let uiUpdateFrequency: TimeInterval = 1

    enum ViewMode {
        case table, graph
    }

    var body: some View {
        VStack {
            Picker("View Mode", selection: $viewMode) {
                Text("Table").tag(ViewMode.table)
                Text("Graph").tag(ViewMode.graph)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if viewMode == .table {
                tableView
            } else {
                graphView
            }
        }
        .onAppear(perform: setupPeriodicUpdates)
        .onReceive(appState.usageTracker.$currentApp) { _ in
            updateUsageData()
        }
    }

    private var tableView: some View {
        List(usageData) { usage in
            HStack {
                Text(usage.appInfo.displayName)
                Spacer()
                Text(TimeUtils.formatTimeInterval(usage.timeSpent))
            }
        }
    }

    private var graphView: some View {
        Chart(usageData) { usage in
            BarMark(
                x: .value("App", usage.appInfo.displayName),
                y: .value("Minutes", usage.timeSpent / 60)
            )
            .foregroundStyle(ColorUtils.colorForApp(usage.appInfo))
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name.prefix(10))
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
        }
        .chartYAxis {
            let maxValue = Int(ceil(usageData.map { $0.timeSpent / 60 }.max() ?? 0))
            let step = max(1, maxValue > 4 ? maxValue / 4 : 1)
            AxisMarks(position: .leading, values: .stride(by: Double(step))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))")
                    }
                }
            }
        }
        .frame(height: 300)
        .padding()
        .animation(.easeInOut, value: usageData)
    }
    
    private func setupPeriodicUpdates() {
        Timer.publish(every: uiUpdateFrequency, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateUsageData()
            }
            .store(in: &appState.usageTracker.cancellables)
        
        updateUsageData()
    }

    private func updateUsageData() {
        usageData = appState.usageTracker.getSortedUsageData()
    }
}
