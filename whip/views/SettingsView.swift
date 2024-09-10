import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingRuleForm = false
    @State private var currentFormData: RuleFormData = RuleFormData()
    @State private var isNewRule = true
    @State private var formId = UUID()

    var body: some View {
        VStack(alignment: .trailing, spacing: 17) {
            if let loadingError = appState.loadingError {
                Text("Error: \(loadingError)")
                    .foregroundColor(.red)
                    .padding()
            }

            addRuleButton

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            rulesList
        }
        .sheet(isPresented: $showingRuleForm) {
            RuleFormView(viewModel: viewModel,
                         isPresented: $showingRuleForm,
                         formData: $currentFormData,
                         isNewRule: isNewRule)
            .id(formId)
        }
        .onChange(of: showingRuleForm) { oldValue, newValue in
            if !newValue {
                // Reset the form when it's dismissed
                formId = UUID()
                currentFormData = RuleFormData()
                isNewRule = true
            }
        }
    }

    private var addRuleButton: some View {
        Button(action: {
            currentFormData = RuleFormData()
            isNewRule = true
            formId = UUID()
            showingRuleForm = true
        }) {
            Image(systemName: "plus")
        }
        .buttonStyle(.bordered)
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
                currentFormData = RuleFormData(app: app, type: type, limit: appState.ruleService.timeLimitRules[app.id])
                isNewRule = false
                formId = UUID()
                showingRuleForm = true
            }
            Button("Remove") {
                viewModel.removeRule(for: app, type: type)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
