import SwiftUI

struct RuleFormView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @Binding var formData: RuleFormData
    let isNewRule: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(isNewRule ? "Add New Rule" : "Edit Rule")
                .font(.headline)

            if isNewRule {
                AppSelector(selection: $formData.app, options: viewModel.installedApps)
            } else if let app = formData.app {
                HStack {
                    app.swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text(app.displayName)
                        .font(.subheadline)
                }
            }

            if isNewRule {
                Picker("Rule Type", selection: $formData.ruleType) {
                    Text("Time Limit").tag(RuleType.limit)
                    Text("Schedule").tag(RuleType.schedule)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            if formData.ruleType == .limit {
                TextField("Time limit (e.g., 1h30m)", text: $formData.timeLimit)
            } else {
                HStack {
                    Picker("Start Hour", selection: $formData.scheduleStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    Picker("Start Minute", selection: $formData.scheduleStartMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }
                HStack {
                    Picker("End Hour", selection: $formData.scheduleEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    Picker("End Minute", selection: $formData.scheduleEndMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }
            }

            HStack {
                Button(isNewRule ? "Add Rule" : "Save Changes") {
                    if isNewRule {
                        viewModel.saveNewRule(formData)
                    } else {
                        viewModel.saveEditedRule(formData)
                    }
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
