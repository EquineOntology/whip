import SwiftUI
import Combine

@MainActor
class UsageStatisticsViewModel: ObservableObject {
    @Published var viewMode: ViewMode {
        didSet {
            UserDefaults.standard.set(viewMode.rawValue, forKey: "usageStatisticsViewMode")
        }
    }
    @Published private(set) var usageData: [AppUsage] = []
    @Published private(set) var visibleApps: [AppUsage] = []

    private let usageTracker: UsageTracker
    private var cancellables = Set<AnyCancellable>()
    private let uiUpdateFrequency: TimeInterval = 1

    enum ViewMode: String {
        case table, graph
    }

    init(usageTracker: UsageTracker) {
        self.usageTracker = usageTracker
        let storedViewMode = UserDefaults.standard.string(forKey: "usageStatisticsViewMode") ?? ViewMode.table.rawValue
        self.viewMode = ViewMode(rawValue: storedViewMode) ?? .table
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
        updateVisibleApps()
    }

    private func updateVisibleApps() {
        visibleApps = Array(usageData.prefix(10))
    }
}
