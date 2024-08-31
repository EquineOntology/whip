import Foundation
import AppKit

class AppInfoManager {
    static let shared = AppInfoManager()
    private var appInfoCache: [String: AppInfo] = [:]
    
    private init() {}
    
    func getAppInfo(forBundleIdentifier bundleIdentifier: String, pid: Int32? = nil) -> AppInfo {
        if let cachedInfo = appInfoCache[bundleIdentifier] {
            return cachedInfo.updatingPID(pid)
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url),
           let displayName = bundle.infoDictionary?["CFBundleName"] as? String ??
            bundle.infoDictionary?["CFBundleDisplayName"] as? String {
            let appInfo = AppInfo(
                id: bundleIdentifier,
                displayName: displayName,
                pid: pid
            )
            appInfoCache[bundleIdentifier] = appInfo
            return appInfo
        }
        // Fallback to using the bundle identifier as the display name
        let appInfo = AppInfo(id: bundleIdentifier, displayName: bundleIdentifier, pid: pid)
        appInfoCache[bundleIdentifier] = appInfo
        return appInfo
    }
    
    func getAppInfo(forRunningApplication app: NSRunningApplication) -> AppInfo {
        let bundleIdentifier = app.bundleIdentifier ?? "unknown"
        return getAppInfo(forBundleIdentifier: bundleIdentifier, pid: app.processIdentifier)
    }
}
