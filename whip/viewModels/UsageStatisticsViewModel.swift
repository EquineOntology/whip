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
    @Published var currentVisibleDate: Date
    @Published private(set) var availableDates: [Date] = []

    private let usageTracker: UsageTracker
    private let appInfoProvider: AppInfoProvider
    private let historicalUsageService: HistoricalUsageService
    private var cancellables = Set<AnyCancellable>()
    private let uiUpdateFrequency: TimeInterval = 1

    enum ViewMode: String {
        case table, graph
    }

    init(usageTracker: UsageTracker, historicalUsageService: HistoricalUsageService, appInfoProvider: AppInfoProvider) {
        self.usageTracker = usageTracker
        let storedViewMode = UserDefaults.standard.string(forKey: "usageStatisticsViewMode") ?? ViewMode.table.rawValue
        self.viewMode = ViewMode(rawValue: storedViewMode) ?? .table
        self.historicalUsageService = historicalUsageService
        self.appInfoProvider = appInfoProvider
        self.currentVisibleDate = Date()

        Task {
            await loadAvailableDates()
            await updateUsageData()
        }
    }

    func setupPeriodicUpdates() {
        Timer.publish(every: uiUpdateFrequency, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.updateUsageData()
                }
            }
            .store(in: &cancellables)
    }

    private func updateUsageData() async {
        let data: [String: TimeInterval]
        if Calendar.current.isDateInToday(currentVisibleDate) {
            data = usageTracker.getCurrentDayUsage()
        } else {
            do {
                data = try historicalUsageService.getUsageData(for: currentVisibleDate)
            } catch {
                // Handle error
                return
            }
        }

        usageData = data.map { bundleId, timeSpent in
            let appInfo = appInfoProvider.getAppInfo(forBundleIdentifier: bundleId)
            return AppUsage(appInfo: appInfo, timeSpent: timeSpent, runningApp: nil)
        }
        .sorted { $0.timeSpent > $1.timeSpent }

        updateVisibleApps()
    }

    private func loadAvailableDates() async {
        do {
            availableDates = try historicalUsageService.getAvailableDates()
        } catch {
            // Handle error
        }
    }

    func navigateToPreviousDay() {
        if let previousDate = availableDates.last(where: { $0 < currentVisibleDate }) {
            currentVisibleDate = previousDate
            Task {
                await updateUsageData()
            }
        }
    }

    func navigateToNextDay() {
        if let nextDate = availableDates.first(where: { $0 > currentVisibleDate }) {
            currentVisibleDate = nextDate
            Task {
                await updateUsageData()
            }
        }
    }

    var canNavigateToPreviousDay: Bool {
        availableDates.contains(where: { $0 < currentVisibleDate })
    }

    var canNavigateToNextDay: Bool {
        availableDates.contains(where: { $0 > currentVisibleDate })
    }

    private func updateVisibleApps() {
        visibleApps = Array(usageData.prefix(10))
    }
}
