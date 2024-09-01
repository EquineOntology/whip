import SwiftUI
import Charts

@MainActor
struct UsageStatisticsView: View {
    @ObservedObject var viewModel: UsageStatisticsViewModel

    var body: some View {
        VStack {
            Picker("View Mode", selection: $viewModel.viewMode) {
                Text("Table").tag(UsageStatisticsViewModel.ViewMode.table)
                Text("Graph").tag(UsageStatisticsViewModel.ViewMode.graph)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if viewModel.viewMode == .table {
                tableView
            } else {
                graphView
            }
        }
        .onAppear(perform: viewModel.setupPeriodicUpdates)
    }

    private var tableView: some View {
        List(viewModel.usageData) { usage in
            HStack {
                Text(usage.appInfo.displayName)
                Spacer()
                Text(TimeUtils.formatTimeInterval(usage.timeSpent))
            }
        }
    }

    private var graphView: some View {
        Chart(viewModel.usageData) { usage in
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
            let maxValue = Int(ceil(viewModel.usageData.map { $0.timeSpent / 60 }.max() ?? 0))
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
        .animation(.easeInOut, value: viewModel.usageData)
    }
}
