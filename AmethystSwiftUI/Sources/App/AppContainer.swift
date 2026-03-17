import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    @Published var section: AppSection = .home

    @Published var profiles: [GameProfile] = [
        GameProfile(name: "Default", version: "1.21.4"),
        GameProfile(name: "Fabric", version: "1.20.1"),
        GameProfile(name: "Forge", version: "1.19.2")
    ]
    @Published var accounts: [LauncherAccount] = [
        LauncherAccount(username: "PlayerOne", provider: "Microsoft")
    ]

    @Published var selectedProfileID: UUID?
    @Published var selectedAccountID: UUID?

    @Published var installerSource: InstallerSource = .modrinth
    @Published var installerQuery = ""
    @Published var installerResults: [InstallerResult] = []
    @Published var curseForgeApiKey = "" {
        didSet { persistInstallerPreferences() }
    }

    @Published var statusText = "Ready"
    @Published var isBusy = false

    @Published var dashboardBackgroundMode: DashboardBackgroundMode = .default {
        didSet { persistDashboardPreferences() }
    }
    @Published var dashboardBackgroundPath = "" {
        didSet { persistDashboardPreferences() }
    }
    @Published var dashboardBlurStrength = 0.42 {
        didSet { persistDashboardPreferences() }
    }
    @Published var dashboardGlassIntensity = 0.62 {
        didSet { persistDashboardPreferences() }
    }

    private let core: LauncherCore
    private let installerSearchClient = InstallerSearchClient()
    private let defaults = UserDefaults.standard

    init(core: LauncherCore) {
        self.core = core
        loadDashboardPreferences()
        loadInstallerPreferences()
        if selectedProfileID == nil {
            selectedProfileID = profiles.first?.id
        }
        if selectedAccountID == nil {
            selectedAccountID = accounts.first?.id
        }
    }

    var selectedProfile: GameProfile? {
        profiles.first(where: { $0.id == selectedProfileID })
    }

    var selectedAccount: LauncherAccount? {
        accounts.first(where: { $0.id == selectedAccountID })
    }

    func launchSelectedProfile() async {
        isBusy = true
        statusText = "Launching..."
        defer { isBusy = false }

        do {
            try await core.launch(profile: selectedProfile, account: selectedAccount)
            statusText = "Game launched"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func searchInstaller() async {
        isBusy = true
        statusText = "Searching \(installerSource.title)..."
        defer { isBusy = false }

        do {
            installerResults = try await installerSearchClient.search(
                source: installerSource,
                query: installerQuery,
                curseForgeApiKey: curseForgeApiKey
            )
            statusText = installerResults.isEmpty ? "No results" : "Found \(installerResults.count) results"
        } catch {
            // Keep demo fallback while bridge is unfinished.
            do {
                installerResults = try await core.search(source: installerSource, query: installerQuery)
                statusText = installerResults.isEmpty
                    ? "No results"
                    : "Found \(installerResults.count) results (fallback)"
            } catch {
                statusText = error.localizedDescription
            }
        }
    }

    func resetBackground() {
        dashboardBackgroundMode = .default
        dashboardBackgroundPath = ""
    }

    func importBackground(data: Data, fileName: String, from mode: DashboardBackgroundMode) throws {
        let ext = (fileName as NSString).pathExtension
        let fileExt = ext.isEmpty ? "png" : ext.lowercased()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let docs else {
            throw LauncherCoreError.generic("Unable to access Documents directory.")
        }
        let outputURL = docs.appendingPathComponent("dashboard_background.\(fileExt)")
        try data.write(to: outputURL, options: .atomic)
        dashboardBackgroundPath = outputURL.path
        dashboardBackgroundMode = mode
    }

    private func loadDashboardPreferences() {
        if let raw = defaults.string(forKey: DashboardPreferenceKeys.backgroundMode),
           let mode = DashboardBackgroundMode(rawValue: raw) {
            dashboardBackgroundMode = mode
        }

        if let savedPath = defaults.string(forKey: DashboardPreferenceKeys.backgroundPath) {
            dashboardBackgroundPath = savedPath
        }

        if defaults.object(forKey: DashboardPreferenceKeys.blurStrength) != nil {
            dashboardBlurStrength = defaults.double(forKey: DashboardPreferenceKeys.blurStrength)
        }

        if defaults.object(forKey: DashboardPreferenceKeys.glassIntensity) != nil {
            dashboardGlassIntensity = defaults.double(forKey: DashboardPreferenceKeys.glassIntensity)
        }
    }

    private func persistDashboardPreferences() {
        defaults.set(dashboardBackgroundMode.rawValue, forKey: DashboardPreferenceKeys.backgroundMode)
        defaults.set(dashboardBackgroundPath, forKey: DashboardPreferenceKeys.backgroundPath)
        defaults.set(dashboardBlurStrength, forKey: DashboardPreferenceKeys.blurStrength)
        defaults.set(dashboardGlassIntensity, forKey: DashboardPreferenceKeys.glassIntensity)
    }

    private func loadInstallerPreferences() {
        if let savedKey = defaults.string(forKey: InstallerPreferenceKeys.curseForgeApiKey) {
            curseForgeApiKey = savedKey
        }
    }

    private func persistInstallerPreferences() {
        defaults.set(curseForgeApiKey, forKey: InstallerPreferenceKeys.curseForgeApiKey)
    }
}
