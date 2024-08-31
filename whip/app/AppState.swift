import SwiftUI
import Combine
import OSLog

@MainActor
class AppState: ObservableObject {
    @Published private(set) var timeLimitSettings: TimeLimitSettings
    @Published private(set) var statisticsManager: StatisticsManager
    @Published private(set) var blockingManager: BlockingManager
    @Published private(set) var usageTracker: UsageTracker
    @Published private(set) var currentApp: AppInfo?

    private let logger = Logger(subsystem: "dev.fratta.whip", category: "AppState")
    private var cancellables = Set<AnyCancellable>()
    
    private var persistenceManager: PersistenceManaging
    private var saveTimer: Timer?
    private let saveInterval: TimeInterval = 30

    private var currentDate: Date = Date()
    private var currentDateAsString: String = TimeUtils.currentDateAsString()

    init() {
        self.persistenceManager = JSONPersistenceManager()
        self.timeLimitSettings = TimeLimitSettings()
        self.statisticsManager = StatisticsManager()
        self.blockingManager = BlockingManager()
        self.usageTracker = UsageTracker()

        blockingManager.setDependencies(usageTracker: usageTracker, timeLimitSettings: timeLimitSettings)
        setupTimeLimitSettingsObserver()

        Task {
            await loadPersistedData()
            configureUsageTracker()
            setupPeriodicSaving()
        }
    }
    
    private func loadPersistedData() async {
        switch persistenceManager.loadTimeLimitRules() {
        case .success(let rules):
            timeLimitSettings.updateRules(rules)
            for (appId, rule) in rules {
                logger.debug("Loaded rule for \(appId): daily limit = \(rule.dailyLimit ?? 0), schedule = \(rule.schedule?.debugDescription() ?? "none")")
            }
        case .failure(let error):
            logger.error("Failed to load time limit rules: \(error.localizedDescription)")
        }

        switch persistenceManager.loadUsageData() {
        case .success(let allUsageData):
            let todayUsage = allUsageData[currentDateAsString] ?? [:]
            usageTracker.setInitialUsageData(todayUsage)
            logger.debug("Loaded usage data for \(self.currentDateAsString): \(todayUsage)")
        case .failure(let error):
            logger.error("Failed to load usage data: \(error.localizedDescription)")
        }
    }
    
    private func saveTimeLimitRules() {
        print("Saving time limit rules:")
        for (appId, rule) in timeLimitSettings.timeLimitRules {
            print("\(appId): \(rule.debugDescription())")
        }
        switch persistenceManager.saveTimeLimitRules(timeLimitSettings.timeLimitRules) {
        case .success:
            logger.debug("Successfully saved time limit rules.")
        case .failure(let error):
            logger.error("Failed to save time limit rules: \(error.localizedDescription)")
        }
    }

    private func saveUsageData() {
        let todayUsage = usageTracker.getAllUsageData()

        switch persistenceManager.loadUsageData() {
        case .success(var allUsageData):
            allUsageData[currentDateAsString] = todayUsage
            switch persistenceManager.saveUsageData(allUsageData) {
            case .success:
                logger.debug("Successfully saved usage data")
            case .failure(let error):
                logger.error("Failed to save usage data: \(error.localizedDescription)")
            }
        case .failure(let error):
            logger.error("Failed to load existing usage data: \(error.localizedDescription)")
        }
    }

    private func setupPeriodicSaving() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveUsageData()
                self.checkAndUpdateDate()
            }
        }
    }
    
    private func setupTimeLimitSettingsObserver() {
        timeLimitSettings.objectWillChange.sink { [weak self] _ in
            self?.saveTimeLimitRules()
        }
        .store(in: &cancellables)
    }

    private func checkAndUpdateDate() {
        let today = Date()
        if !Calendar.current.isDate(currentDate, inSameDayAs: today) {
            currentDate = today
            currentDateAsString = TimeUtils.currentDateAsString()
            usageTracker.resetDailyUsage()
            logger.info("Date changed to \(self.currentDateAsString). Reset daily usage.")
        }
    }

    private func configureUsageTracker() {
        usageTracker.setStatisticsManager(statisticsManager)
        usageTracker.startTracking()

        usageTracker.$currentApp
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentApp)
    }

    func performCleanup() {
        saveTimer?.invalidate()
        saveUsageData()
        usageTracker.stopTracking()
    }
}
