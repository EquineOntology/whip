import SwiftUI

struct SettingsFormView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
        self._viewModel = ObservedObject(wrappedValue: SettingsViewModel(ruleService: appState.ruleService))
    }

    var body: some View {
        VStack(spacing: 20) {
            Button("Add Rule") { viewModel.showingAddRuleForm = true }

            if viewModel.showingAddRuleForm {
                addRuleForm
            }

            if let editingRule = viewModel.editingRule {
                editRuleForm(rule: editingRule)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            rulesList
        }
        .padding()
        .frame(width: 800, height: 600)
    }

    private var addRuleForm: some View {
        VStack {
            AppSelector(selection: $viewModel.newRule.app, options: viewModel.installedApps)
            Picker("Rule Type", selection: $viewModel.newRule.ruleType) {
                Text("Time Limit").tag(RuleType.limit)
                Text("Schedule").tag(RuleType.schedule)
            }
            .pickerStyle(SegmentedPickerStyle())

            if viewModel.newRule.ruleType == .limit {
                TextField("Time limit (e.g., 1h30m)", text: $viewModel.newRule.timeLimit)
            } else {
                DatePicker("Start Time", selection: $viewModel.newRule.startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $viewModel.newRule.endTime, displayedComponents: .hourAndMinute)
            }

            HStack {
                Button("Save") { viewModel.saveNewRule() }.foregroundColor(.green)
                Button("Cancel") { viewModel.showingAddRuleForm = false }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .frame(maxWidth: 300)
    }

    private func editRuleForm(rule: RuleFormData) -> some View {
        VStack {
            Text("Editing Rule for \(rule.app?.displayName ?? "")")

            if rule.ruleType == .limit {
                TextField("Time limit (e.g., 1h30m)", text: Binding(
                    get: { rule.timeLimit },
                    set: { viewModel.editingRule?.timeLimit = $0 }
                ))
            } else {
                DatePicker("Start Time", selection: Binding(
                    get: { rule.startTime },
                    set: { viewModel.editingRule?.startTime = $0 }
                ), displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: Binding(
                    get: { rule.endTime },
                    set: { viewModel.editingRule?.endTime = $0 }
                ), displayedComponents: .hourAndMinute)
            }

            HStack {
                Button("Save") { viewModel.saveEditedRule() }.foregroundColor(.green)
                Button("Cancel") { viewModel.editingRule = nil }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .frame(maxWidth: 300)
    }

    private var rulesList: some View {
        List {
            ForEach(viewModel.installedApps.sorted(by: { $0.displayName < $1.displayName })) { app in
                if let limit = appState.ruleService.timeLimitRules[app.id] {
                    if let dailyLimit = limit.dailyLimit {
                        ruleRow(app: app, type: .limit, data: TimeUtils.formatTimeInterval(dailyLimit))
                    }
                    if let schedule = limit.schedule {
                        ruleRow(app: app, type: .schedule, data: schedule.toString())
                    }
                }
            }
        }
        .id(viewModel.forceUpdate)
    }

    private func ruleRow(app: AppInfo, type: RuleType, data: String) -> some View {
        HStack {
            app.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
            Text(app.displayName)
            Spacer()
            Image(systemName: type == .limit ? "clock" : "calendar")
            Text(data)
            Button("Edit") {
                viewModel.editRule(for: app, type: type)
            }
            Button("Remove") {
                viewModel.removeRule(for: app, type: type)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
