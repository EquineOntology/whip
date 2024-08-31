import Foundation

struct AppInfo: Identifiable, Codable {
    let id: String // This is the app's bundle identifier
    let displayName: String
    let pid: Int32?

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.displayName == rhs.displayName && lhs.pid == rhs.pid
    }

    func updatingPID(_ newPID: Int32?) -> AppInfo {
        AppInfo(id: self.id, displayName: self.displayName, pid: newPID ?? self.pid)
    }
}
