import SwiftUI

struct AppInfoWithIcon: Identifiable, Equatable, Hashable {
    let appInfo: AppInfo
    let icon: NSImage
    let uniqueId: UUID

    var id: String { uniqueId.uuidString }
    var displayName: String { appInfo.displayName }

    init(appInfo: AppInfo, icon: NSImage) {
        self.appInfo = appInfo
        self.icon = icon
        self.uniqueId = UUID()
    }

    static func == (lhs: AppInfoWithIcon, rhs: AppInfoWithIcon) -> Bool {
        return lhs.appInfo.id == rhs.appInfo.id && lhs.uniqueId == rhs.uniqueId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(appInfo.id)
        hasher.combine(uniqueId)
    }
}
