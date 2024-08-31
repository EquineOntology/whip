import SwiftUI

struct SettingsFormView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddScheduleForm = false
    @State private var showingAddLimitForm = false
    @State private var editingRule: EditingRule?
    @State private var newSchedule = NewSchedule()
    @State private var newLimit = NewLimit()
    @State private var installedApps: [AppInfoWithIcon] = []
    @State private var errorMessage: String?
    @State private var forceUpdate: Bool = false

    struct NewSchedule {
        var selectedApp: AppInfoWithIcon?
        var startTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        var endTime: Date = Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
    }

    struct NewLimit {
        var selectedApp: AppInfoWithIcon?
        var timeLimit: String = ""
    }

    struct EditingRule {
        let app: AppInfoWithIcon
        let type: RuleType
        var startTime: Date
        var endTime: Date
        var timeLimit: String

        init(app: AppInfoWithIcon, type: RuleType, limit: TimeLimit) {
            self.app = app
            self.type = type
            self.startTime = limit.schedule?.start ?? Date()
            self.endTime = limit.schedule?.end ?? Date()
            self.timeLimit = limit.dailyLimit.map { TimeUtils.formatTimeInterval($0) } ?? ""
        }
    }

    enum RuleType {
        case limit
        case schedule
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Add Schedule") { showingAddScheduleForm = true }
                Button("Add Limit") { showingAddLimitForm = true }
            }

            if showingAddScheduleForm {
                addScheduleForm.frame(maxWidth: 300)
            }

            if showingAddLimitForm {
                addLimitForm.frame(maxWidth: 300)
            }

            if let editingRule = editingRule {
                editRuleForm(rule: editingRule).frame(maxWidth: 300)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            List {
                ForEach(installedApps.sorted(by: { $0.displayName < $1.displayName }), id: \.appInfo.id) { app in
                    if let limit = appState.timeLimitSettings.timeLimitRules[app.appInfo.id] {
                        if let dailyLimit = limit.dailyLimit {
                            ruleRow(app: app, type: .limit, data: TimeUtils.formatTimeInterval(dailyLimit))
                        }
                        if let schedule = limit.schedule {
                            ruleRow(app: app, type: .schedule, data: formatSchedule(schedule))
                        }
                    }
                }
            }
            .id(forceUpdate)
        }
        .padding()
        .frame(width: 800, height: 600)
        .onAppear(perform: loadInstalledApps)
    }

    private var addScheduleForm: some View {
        VStack {
            AppSelector(selection: $newSchedule.selectedApp, options: installedApps)
            DatePicker("Start Time", selection: $newSchedule.startTime, displayedComponents: .hourAndMinute)
            DatePicker("End Time", selection: $newSchedule.endTime, displayedComponents: .hourAndMinute)
            HStack {
                Button("Save") { saveNewSchedule() }.foregroundColor(.green)
                Button("Cancel") { showingAddScheduleForm = false }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
    }

    private var addLimitForm: some View {
        VStack {
            AppSelector(selection: $newLimit.selectedApp, options: installedApps)
            TextField("Time limit (e.g., 1h30m)", text: $newLimit.timeLimit)
            HStack {
                Button("Save") { saveNewLimit() }.foregroundColor(.green)
                Button("Cancel") { showingAddLimitForm = false }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
    }

    private func editRuleForm(rule: EditingRule) -> some View {
        VStack {
            Text("Editing \(rule.type == .limit ? "Time Limit" : "Schedule") for \(rule.app.displayName)")
            if rule.type == .schedule {
                DatePicker("Start Time", selection: Binding(
                    get: { rule.startTime },
                    set: { editingRule?.startTime = $0 }
                ), displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: Binding(
                    get: { rule.endTime },
                    set: { editingRule?.endTime = $0 }
                ), displayedComponents: .hourAndMinute)
            } else {
                TextField("Time limit (e.g., 1h30m)", text: Binding(
                    get: { rule.timeLimit },
                    set: { editingRule?.timeLimit = $0 }
                ))
            }
            HStack {
                Button("Save") { saveEditedRule() }.foregroundColor(.green)
                Button("Cancel") { editingRule = nil }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
    }

    private func ruleRow(app: AppInfoWithIcon, type: RuleType, data: String) -> some View {
        HStack {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
            Text(app.displayName)
            Spacer()
            Image(systemName: type == .limit ? "clock" : "calendar")
            Text(data)
            Button("Edit") {
                editRule(for: app, type: type)
            }
            Button("Remove") {
                removeRule(for: app.appInfo, type: type)
                forceUpdate.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func saveNewSchedule() {
        guard let selectedApp = newSchedule.selectedApp else {
            errorMessage = "Please select an app"
            return
        }

        let schedule = Schedule(start: newSchedule.startTime, end: newSchedule.endTime)
        if validateSchedule(appId: selectedApp.appInfo.id, newSchedule: schedule) {
            appState.timeLimitSettings.updateSchedule(for: selectedApp.appInfo, schedule: schedule)
            showingAddScheduleForm = false
            newSchedule = NewSchedule()
            errorMessage = nil
        } else {
            errorMessage = "Invalid schedule. Please check for conflicts."
        }
    }

    private func saveNewLimit() {
        guard let selectedApp = newLimit.selectedApp else {
            errorMessage = "Please select an app"
            return
        }

        if let seconds = parseTimeInput(newLimit.timeLimit) {
            appState.timeLimitSettings.setTimeLimit(for: selectedApp.appInfo, seconds: seconds)
            showingAddLimitForm = false
            newLimit = NewLimit()
            errorMessage = nil
        } else {
            errorMessage = "Invalid time limit format"
        }
    }

    private func editRule(for app: AppInfoWithIcon, type: RuleType) {
        if let limit = appState.timeLimitSettings.timeLimitRules[app.appInfo.id] {
            editingRule = EditingRule(app: app, type: type, limit: limit)
        }
    }

    private func saveEditedRule() {
        guard let rule = editingRule else { return }

        if rule.type == .schedule {
            let schedule = Schedule(start: rule.startTime, end: rule.endTime)
            if validateSchedule(appId: rule.app.appInfo.id, newSchedule: schedule) {
                appState.timeLimitSettings.updateSchedule(for: rule.app.appInfo, schedule: schedule)
                editingRule = nil
                errorMessage = nil
            } else {
                errorMessage = "Invalid schedule. Please check for conflicts."
            }
        } else {
            if let seconds = parseTimeInput(rule.timeLimit) {
                appState.timeLimitSettings.setTimeLimit(for: rule.app.appInfo, seconds: seconds)
                editingRule = nil
                errorMessage = nil
            } else {
                errorMessage = "Invalid time limit format"
            }
        }
    }

    private func removeRule(for appInfo: AppInfo, type: RuleType) {
        switch type {
        case .limit:
            appState.timeLimitSettings.clearTimeLimit(for: appInfo)
        case .schedule:
            appState.timeLimitSettings.clearSchedule(for: appInfo)
        }
        forceUpdate.toggle()
    }

    private func parseTimeInput(_ input: String) -> TimeInterval? {
        let pattern = #"(\d+)\s*([hms])"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, options: [], range: nsRange)

        var totalSeconds: TimeInterval = 0

        for match in matches {
            guard let valueRange = Range(match.range(at: 1), in: input),
                  let unitRange = Range(match.range(at: 2), in: input),
                  let value = Double(input[valueRange]) else {
                continue
            }

            let unit = input[unitRange].lowercased()

            switch unit {
            case "h": totalSeconds += value * 3600
            case "m": totalSeconds += value * 60
            case "s": totalSeconds += value
            default: return nil
            }
        }

        return totalSeconds > 0 ? totalSeconds : nil
    }

    func formatSchedule(_ schedule: Schedule) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: schedule.start)) - \(formatter.string(from: schedule.end))"
    }

    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let workspace = NSWorkspace.shared
            guard let applications = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first else {
                return
            }

            let enumerator = FileManager.default.enumerator(at: applications, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])

            var apps: [AppInfoWithIcon] = []

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
                        let appInfo = AppInfo(id: bundleIdentifier, displayName: displayName, pid: nil)
                        let icon = workspace.icon(forFile: url.path)
                        let appInfoWithIcon = AppInfoWithIcon(appInfo: appInfo, icon: icon)
                        apps.append(appInfoWithIcon)
                    }
                }
            }

            DispatchQueue.main.async {
                self.installedApps = apps.sorted { $0.displayName < $1.displayName }
            }
        }
    }

    private func validateSchedule(appId: String, newSchedule: Schedule) -> Bool {
        for (id, limit) in appState.timeLimitSettings.timeLimitRules {
            if id != appId, let existingSchedule = limit.schedule {
                if newSchedule.start < existingSchedule.end && newSchedule.end > existingSchedule.start {
                    return false
                }
            }
        }
        return true
    }
}
