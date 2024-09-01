import SwiftUI

struct AppInfo: Identifiable, Codable, Equatable, Hashable {
    let id: String // The app's bundle identifier
    let displayName: String
    var icon: NSImage?

    var uniqueId: String { id }

    var swiftUIImage: Image {
        icon.map(Image.init) ?? Image(systemName: "app.square")
    }

    init(id: String, displayName: String, icon: NSImage? = nil) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.displayName == rhs.displayName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(displayName)
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, pid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        icon = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
    }
}
