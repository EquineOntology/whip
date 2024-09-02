import SwiftUI
import Combine

@MainActor
class UsageStatisticsViewModel: ObservableObject {
    @Published var viewMode: ViewMode = .table
    @Published var usageData: [AppUsage] = []

    private let usageTracker: UsageTracker
    private var cancellables = Set<AnyCancellable>()
    private let uiUpdateFrequency: TimeInterval = 1

    enum ViewMode {
        case table, graph
    }

    init(usageTracker: UsageTracker) {
        self.usageTracker = usageTracker
        setupObservers()
    }

    func setupPeriodicUpdates() {
        Timer.publish(every: uiUpdateFrequency, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateUsageData() }
            .store(in: &cancellables)

        updateUsageData()
    }

    private func setupObservers() {
        usageTracker.$currentApp
            .sink { [weak self] _ in self?.updateUsageData() }
            .store(in: &cancellables)
    }

    private func updateUsageData() {
        usageData = usageTracker.getSortedUsageData()
    }
}
