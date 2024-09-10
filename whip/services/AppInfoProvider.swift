import AppKit

class AppInfoProvider {
    private var appInfoCache: [String: AppInfo] = [:]

    func getAppInfo(forBundleIdentifier bundleId: String) -> AppInfo {
        if let cachedInfo = appInfoCache[bundleId] {
            return cachedInfo
        }

        let workspace = NSWorkspace.shared
        if let appUrl = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = (appUrl.lastPathComponent as NSString).deletingPathExtension
            let icon = workspace.icon(forFile: appUrl.path)
            let appInfo = AppInfo(id: bundleId, displayName: appName, icon: icon)
            appInfoCache[bundleId] = appInfo
            return appInfo
        }

        // Fallback if app info can't be found
        return AppInfo(id: bundleId, displayName: bundleId)
    }
}
