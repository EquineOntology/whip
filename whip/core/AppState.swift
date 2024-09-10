import SwiftUI
import Combine
import OSLog

@MainActor
class AppState: ObservableObject {
    @Published private(set) var ruleService: RuleService
    @Published private(set) var blockingService: BlockingService
    @Published private(set) var usageTracker: UsageTracker
    @Published private(set) var notificationService: NotificationService
    @Published private(set) var currentApp: AppInfo?
    @Published var loadingError: String?

    private let logger = Logger(subsystem: "dev.fratta.whip", category: "AppState")
    private var cancellables = Set<AnyCancellable>()
    private let persistenceManager: PersistenceManaging
    private var saveTimer: Timer?
    private let saveInterval: TimeInterval = 30

    let historicalUsageService: HistoricalUsageService
    private var currentDate: Date = Date()
    private var currentDateAsString: String = TimeUtils.dateAsString()
    
    let appInfoProvider: AppInfoProvider

    init(persistenceManager: PersistenceManaging = JSONPersistenceManager()) {
        self.persistenceManager = persistenceManager
        self.ruleService = RuleService(persistenceManager: persistenceManager)
        self.historicalUsageService = HistoricalUsageService(persistenceManager: persistenceManager)
        self.notificationService = NotificationService()
        self.blockingService = BlockingService()
        self.usageTracker = UsageTracker()
        self.appInfoProvider = AppInfoProvider()

        blockingService.setDependencies(usageTracker: usageTracker, ruleService: ruleService, notificationService: notificationService)
        setupTimeLimitSettingsObserver()

        Task {
            await loadPersistedData()
            configureUsageTracker()
            setupPeriodicSaving()
            notificationService.requestAuthorization()
        }
    }

    private func loadPersistedData() async {
        do {
            let rules = try persistenceManager.loadTimeLimitRules()
            ruleService.updateRules(rules)
            for (appId, rule) in rules {
                logger.debug("Loaded rule for \(appId): daily limit = \(rule.dailyLimit ?? 0), schedule = \(rule.schedule?.toString() ?? "none")")
            }
        } catch {
            logger.error("Failed to load time limit rules: \(error.localizedDescription)")
            loadingError = "Failed to load rules: \(error.localizedDescription)"
        }

        do {
            let allUsageData = try persistenceManager.loadUsageData()
            let todayUsage = allUsageData[currentDateAsString] ?? [:]
            usageTracker.setInitialUsageData(todayUsage)
            logger.debug("Loaded usage data for \(self.currentDateAsString): \(todayUsage)")
        } catch {
            logger.error("Failed to load usage data: \(error.localizedDescription)")
            loadingError = (loadingError ?? "") + "\nFailed to load usage data: \(error.localizedDescription)"
        }
    }

    private func saveTimeLimitRules() {
        do {
            try persistenceManager.saveTimeLimitRules(ruleService.timeLimitRules)
            logger.debug("Successfully saved time limit rules.")
        } catch {
            logger.error("Failed to save time limit rules: \(error.localizedDescription)")
        }
    }

    private func saveUsageData() {
        let todayUsage = usageTracker.getCurrentDayUsage()
        do {
            var allUsageData = try persistenceManager.loadUsageData()
            allUsageData[currentDateAsString] = todayUsage
            try persistenceManager.saveUsageData(allUsageData)
            logger.debug("Successfully saved usage data")
        } catch {
            logger.error("Failed to save usage data: \(error.localizedDescription)")
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
        ruleService.objectWillChange.sink { [weak self] _ in
            self?.saveTimeLimitRules()
        }
        .store(in: &cancellables)
    }

    private func checkAndUpdateDate() {
        let today = Date()
        if !Calendar.current.isDate(currentDate, inSameDayAs: today) {
            currentDate = today
            currentDateAsString = TimeUtils.dateAsString()
            usageTracker.resetDailyUsage()
            logger.info("Date changed to \(self.currentDateAsString). Reset daily usage.")
        }
    }

    private func configureUsageTracker() {
        usageTracker.startTracking()

        usageTracker.$currentApp
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentApp)
    }

    func performCleanup() {
        saveTimer?.invalidate()
        saveUsageData()
        usageTracker.stopTracking()
        blockingService.cleanup()
    }
}
