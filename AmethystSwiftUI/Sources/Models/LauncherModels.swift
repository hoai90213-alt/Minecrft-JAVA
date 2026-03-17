import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case profiles
    case installer
    case accounts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .profiles: return "Profiles"
        case .installer: return "Installer"
        case .accounts: return "Accounts"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .profiles: return "square.stack.3d.up.fill"
        case .installer: return "shippingbox.fill"
        case .accounts: return "person.2.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct GameProfile: Identifiable, Hashable {
    let id: UUID
    var name: String
    var version: String
    var lastPlayed: Date?

    init(id: UUID = UUID(), name: String, version: String, lastPlayed: Date? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.lastPlayed = lastPlayed
    }
}

struct LauncherAccount: Identifiable, Hashable {
    let id: UUID
    var username: String
    var provider: String

    init(id: UUID = UUID(), username: String, provider: String) {
        self.id = id
        self.username = username
        self.provider = provider
    }
}

enum InstallerSource: String, CaseIterable, Identifiable {
    case modrinth
    case curseforge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modrinth: return "Modrinth"
        case .curseforge: return "CurseForge"
        }
    }
}

struct InstallerResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
}

enum DashboardBackgroundMode: String, CaseIterable, Identifiable {
    case `default`
    case photos
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: return "Default"
        case .photos: return "Photos"
        case .files: return "Files"
        }
    }
}
