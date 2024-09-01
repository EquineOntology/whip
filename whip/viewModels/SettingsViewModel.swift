import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var showingAddRuleForm = false
    @Published var editingRule: RuleFormData?
    @Published var newRule = RuleFormData()
    @Published var installedApps: [AppInfo] = []
    @Published var errorMessage: String?
    @Published var forceUpdate = false

    private var cancellables = Set<AnyCancellable>()
    private let ruleService: RuleService

    init(ruleService: RuleService) {
        self.ruleService = ruleService
        setupObservers()
        installedApps = fetchInstalledApps()
    }

    func saveNewRule() {
        guard let selectedApp = newRule.app else {
            errorMessage = "Please select an app"
            return
        }

        switch newRule.ruleType {
        case .limit:
            if let seconds = TimeUtils.IntervalFromDurationString(newRule.timeLimit) {
                ruleService.setTimeLimit(for: selectedApp, seconds: seconds)
                showingAddRuleForm = false
                newRule = RuleFormData()
                errorMessage = nil
            } else {
                errorMessage = "Invalid time limit format"
            }
        case .schedule:
            let schedule = Schedule(start: newRule.startTime, end: newRule.endTime)
            if validateSchedule(appId: selectedApp.id, newSchedule: schedule) {
                ruleService.setSchedule(for: selectedApp, schedule: schedule)
                showingAddRuleForm = false
                newRule = RuleFormData()
                errorMessage = nil
            } else {
                errorMessage = "Invalid schedule. Please check for conflicts."
            }
        }
    }

    func editRule(for app: AppInfo, type: RuleType) {
        if let limit = ruleService.timeLimitRules[app.id] {
            editingRule = RuleFormData(app: app, type: type, limit: limit)
        }
    }

    func saveEditedRule() {
        guard let rule = editingRule, let app = rule.app else { return }

        switch rule.ruleType {
        case .limit:
            if let seconds = TimeUtils.IntervalFromDurationString(rule.timeLimit) {
                ruleService.setTimeLimit(for: app, seconds: seconds)
            }
        case .schedule:
            let schedule = Schedule(start: rule.startTime, end: rule.endTime)
            if validateSchedule(appId: app.id, newSchedule: schedule) {
                ruleService.setSchedule(for: app, schedule: schedule)
            } else {
                errorMessage = "Invalid schedule. Please check for conflicts."
                return
            }
        }
        editingRule = nil
        errorMessage = nil
    }

    func removeRule(for appInfo: AppInfo, type: RuleType) {
        switch type {
        case .limit:
            ruleService.clearTimeLimit(for: appInfo)
        case .schedule:
            ruleService.clearSchedule(for: appInfo)
        }
        forceUpdate.toggle()
    }

    private func fetchInstalledApps() -> [AppInfo] {
        let workspace = NSWorkspace.shared
        guard let applications = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first else {
            return []
        }

        let enumerator = FileManager.default.enumerator(at: applications, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])

        var apps: [AppInfo] = []

        while let url = enumerator?.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isApplicationKey]),
                  let isApplication = resourceValues.isApplication,
                  isApplication else {
                continue
            }

            if let bundle = Bundle(url: url),
               let bundleIdentifier = bundle.bundleIdentifier,
               let displayName = bundle.infoDictionary?["CFBundleName"] as? String ??
                bundle.infoDictionary?["CFBundleDisplayName"] as? String {

                if !bundleIdentifier.starts(with: "com.apple.") {
                    let appInfo = AppInfo(
                        id: bundleIdentifier,
                        displayName: displayName,
                        icon: workspace.icon(forFile: url.path)
                    )
                    apps.append(appInfo)
                }
            }
        }

        return apps.sorted { $0.displayName < $1.displayName }
    }

    private func setupObservers() {
        ruleService.$timeLimitRules
            .sink { [weak self] _ in
                self?.forceUpdate.toggle()
            }
            .store(in: &cancellables)
    }

    private func validateSchedule(appId: String, newSchedule: Schedule) -> Bool {
        for (id, limit) in ruleService.timeLimitRules {
            if id != appId, let existingSchedule = limit.schedule {
                if newSchedule.start < existingSchedule.end && newSchedule.end > existingSchedule.start {
                    return false
                }
            }
        }
        return true
    }
}
