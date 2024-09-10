import SwiftUI
import Charts

@MainActor
struct UsageStatisticsView: View {
    @ObservedObject var viewModel: UsageStatisticsViewModel

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                dateNavigationButtons
                Spacer()
                viewModeSelector
            }

            Text(TimeUtils.dateAsString(viewModel.currentVisibleDate))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            if viewModel.viewMode == .table {
                tableView
            } else {
                graphView
            }
        }
        .onAppear(perform: viewModel.setupPeriodicUpdates)
    }

    private var dateNavigationButtons: some View {
        HStack {
            Button(action: viewModel.navigateToPreviousDay) {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canNavigateToPreviousDay)

            Button(action: viewModel.navigateToNextDay) {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canNavigateToNextDay)
        }
    }

    private var viewModeSelector: some View {
        Picker("", selection: $viewModel.viewMode) {
            Image(systemName: "list.bullet").tag(UsageStatisticsViewModel.ViewMode.table)
            Image(systemName: "chart.bar").tag(UsageStatisticsViewModel.ViewMode.graph)
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
    }

    private var tableView: some View {
        List(viewModel.visibleApps) { usage in
            HStack {
                Image(nsImage: usage.appInfo.icon ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text(usage.appInfo.displayName)
                Spacer()
                Text(TimeUtils.formatTimeInterval(usage.timeSpent))
            }
        }
    }

    private var graphView: some View {
        Chart(viewModel.visibleApps) { usage in
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
            let maxValue = Int(ceil(viewModel.visibleApps.map { $0.timeSpent / 60 }.max() ?? 0))
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
        .animation(.easeInOut, value: viewModel.visibleApps)
    }
}
