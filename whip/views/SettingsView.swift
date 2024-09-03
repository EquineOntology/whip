import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddRuleSheet = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 17) {
            addRuleButton

            if let editingRule = viewModel.editingRule {
                editRuleForm(rule: editingRule)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            rulesList
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleView(viewModel: viewModel, isPresented: $showingAddRuleSheet)
        }
    }

    private var addRuleButton: some View {
        Button(action: { showingAddRuleSheet = true }) {
            Image(systemName: "plus")
        }
        .buttonStyle(.bordered)
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
