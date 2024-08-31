import SwiftUI

struct SettingsFormView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedApp: AppInfoWithIcon?
    @State private var timeLimit: String = ""
    @State private var errorMessage: String?
    @State private var installedApps: [AppInfoWithIcon] = []

    @State private var forceUpdate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                AppSelector(selection: $selectedApp, options: installedApps)
                    .frame(width: 250)
                
                TextField("Time limit (e.g., 1h30m)", text: $timeLimit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
                
                Button("Add Time Limit") {
                    addTimeLimit()
                }
                .disabled(selectedApp == nil || timeLimit.isEmpty)
            }
            .frame(height: 30)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            List {
                ForEach(Array(appState.timeLimitSettings.timeLimitRules.sorted(by: { $0.key < $1.key })), id: \.key) { appId, limit in
                    HStack {
                        if let app = installedApps.first(where: { $0.appInfo.id == appId }) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text(app.displayName)
                        } else {
                            Text(AppInfoManager.shared.getAppInfo(forBundleIdentifier: appId).displayName)
                        }
                        Spacer()
                        Text(formatTimeInterval(limit))
                        Button(action: {
                            appState.timeLimitSettings.removeApp(AppInfo(id: appId, displayName: "", pid: nil))
                            forceUpdate.toggle()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .padding(3)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .background(Color.red)
                        .cornerRadius(4)
                        .frame(width: 30, height: 20)
                    }
                }
            }
            .id(forceUpdate)
        }
        .padding()
        .frame(width: 800, height: 600)
        .onAppear(perform: loadInstalledApps)
    }

    private func addTimeLimit() {
        guard let selectedApp = selectedApp else {
            errorMessage = "Please select an app"
            return
        }

        guard let seconds = parseTimeInput(timeLimit) else {
            errorMessage = "Invalid time format"
            return
        }

        appState.timeLimitSettings.setTimeLimit(for: selectedApp.appInfo, seconds: seconds)

        // Reset form
        self.selectedApp = nil
        timeLimit = ""
        errorMessage = nil
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

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
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
}
