import Foundation

enum LauncherCoreError: Error, LocalizedError {
    case notImplemented(String)
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message): return message
        case .generic(let message): return message
        }
    }
}

protocol LauncherCore {
    func launch(profile: GameProfile?, account: LauncherAccount?) async throws
    func search(source: InstallerSource, query: String) async throws -> [InstallerResult]
}

struct MockLauncherCore: LauncherCore {
    func launch(profile: GameProfile?, account: LauncherAccount?) async throws {
        try await Task.sleep(nanoseconds: 650_000_000)
        if profile == nil {
            throw LauncherCoreError.generic("Select a profile before launching.")
        }
        if account == nil {
            throw LauncherCoreError.generic("Select an account before launching.")
        }
    }

    func search(source: InstallerSource, query: String) async throws -> [InstallerResult] {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return [
            InstallerResult(title: "\(query) Pack A", subtitle: "\(source.title) result"),
            InstallerResult(title: "\(query) Pack B", subtitle: "\(source.title) result"),
            InstallerResult(title: "\(query) Pack C", subtitle: "\(source.title) result")
        ]
    }
}

struct ObjCLauncherBridge: LauncherCore {
    func launch(profile: GameProfile?, account: LauncherAccount?) async throws {
        throw LauncherCoreError.notImplemented(
            "Bridge not wired. Connect this call to Objective-C launcher runtime."
        )
    }

    func search(source: InstallerSource, query: String) async throws -> [InstallerResult] {
        throw LauncherCoreError.notImplemented(
            "Bridge not wired. Connect this call to installer APIs."
        )
    }
}
