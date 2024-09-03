import SwiftUI

struct AddRuleView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Rule").font(.headline)
            
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
                Button("Save") {
                    viewModel.saveNewRule()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
